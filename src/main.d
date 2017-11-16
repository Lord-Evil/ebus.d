module main;
//our modules
import imports;
import Bus;
import butils;

BGroup[string] groups;
Json config;

void main(){
	string ver = import("version.txt").strip();
	writeln("Starting EBus build "~ver);
	config=parseJsonString(cast(string)std.file.read("config.json"));
	writeln("Server started!");
	auto router = new URLRouter;
	router
		.post("/push/:group/:action",&httpEventHandler)
		.get("/ws",handleWebSockets(&handleConn));

	auto settings = new HTTPServerSettings;
	settings.port = config["port"].get!ushort;
	settings.sessionStore = new MemorySessionStore;
	settings.bindAddresses = [config["bind"].get!string];
	settings.useCompressionIfPossible=true;
	settings.serverString="ebus.d/1.0.0";
	//settings.errorPageHandler = toDelegate(&errorPage);
	listenHTTP(settings, router);
	runApplication();
}
void httpEventHandler(HTTPServerRequest req, HTTPServerResponse res){
	string group_name=req.params["group"];
	string action=req.params["action"];
	if (group_name !in groups){
		groups[group_name] = new BGroup(group_name);
		//writeln("Created new group "~group_name);
	}else{
		//writeln("Existing group "~group_name);
	}
	switch(action){
		case "invoke":
			writeln("Invoke for group "~group_name);
			Json data=req.json;
			writeln(data);

			Json busMsg=Json.emptyObject;
			if(config["auth"].get!bool){
				try{
					busMsg["group"]=reGroup[group_name];	
				}catch(Exception e){}
			}else{
				busMsg["group"] = group_name;
			}
			busMsg["action"] = "invoke";
			busMsg["event"] = Json.emptyObject;
			Json tags;
			if(data.type==Json.Type.object&&data["tags"].type != Json.Type.undefined){
				tags = data["tags"];
				busMsg["event"]["tags"]=tags;
				if(data["data"].type != Json.Type.undefined)
					busMsg["data"] = data["data"];
			}else{
				tags=data;
				busMsg["event"]["tags"]=tags;
			}
			writeln("Invoke tags "~tags.toString());
			auto subs=groups[group_name].findSubscriptionsForInvoke(tags);
			if(subs.length < 1) break;

			foreach(Bus.BSubscription sub; subs) {
				foreach(string seq, WebSocket s; sub.subscribers) {
					busMsg["seqID"] = seq;
					busMsg["event"]["matchedTags"]=deserializeTags(sub.tags);
					s.send(busMsg.toString());
				}
			}
			break;
		default:break;
	}
	res.writeJsonBody(["status":"OK"]);
}
WebSocket[] m_socks;
string[string] reGroup;

void handleConn(scope WebSocket sock)
{
	writeln("Incomming connection! "~sock.request.clientAddress.to!string~" "~sock.request.headers["Sec-WebSocket-Key"]);
	//writeln(sock.request.headers);
	m_socks~=sock;
	Bus.BSubscription[] m_subs;
	while (sock.waitForData()) {
		string msg = sock.receiveText();
		Json data;
		string seqID;
		try{
			/* Format: 
				{
					"group": <string name>,
					"action": "subscribe/invoke/etc",
					["seq": "ad19690109566ab3",]
					["tags": Json,]
					["data": Json]
			*/
			data = parseJsonString(msg);
			writeln(data);
			seqID=data["seq"].get!string;
		}catch(Exception e){
			writeln("#####ERROR####");
			writeln(e.msg);
			writeln(msg);
			writeln("##############");
			continue;
		}

		// TODO: add data in queue and do stuff in other place
		if(data["group"].type!=Json.Type.undefined){
			string group_name = data["group"].get!string;
			if(config["auth"].get!bool){
				string rname=resolveGroup(group_name,config["authUrl"].get!string,config["authKey"].get!string);
				if(rname.length>1){
					reGroup[rname]=group_name;
					group_name=rname;
				}
			}
			if (group_name !in groups){
				groups[group_name] = new BGroup(group_name);
				//writeln("Created new group "~group_name);
			}else{
				//writeln("Existing group "~group_name);
			}
			if(data["action"].type!=Json.Type.undefined){
				string action = data["action"].get!string;
				switch(action){
					case "join":
						//no real purpose, could be used for member count or auth (via tokens etc)
						writeln("Join group "~group_name);
						break;
					case "subscribe":
						if(data["tags"].type==Json.Type.undefined) break;
						Json tags = data["tags"];
						if(tags.length>0) {
							m_subs~=groups[group_name].Subscribe(tags, sock, seqID);
						}
						writeln("Subscripe for tags "~tags.toString());
						break;
					case "request":
						
						break;
					case "chat":
						
						break;

					case "invoke":
						if(data["tags"].type==Json.Type.undefined) break;
						Json tags = data["tags"];
						writeln("Invoke tags "~tags.toString());
						auto subs=groups[group_name].findSubscriptionsForInvoke(tags);
						if(subs.length < 1) break;
						Json busMsg=Json.emptyObject;
						if(config["auth"].get!bool){
							try{
								busMsg["group"]=reGroup[group_name];	
							}catch(Exception e){}
						}else{
							busMsg["group"] = group_name;
						}
						busMsg["action"] = "invoke";
						busMsg["event"] = Json.emptyObject;
						busMsg["event"]["tags"]=tags;
						if(data["data"].type != Json.Type.undefined)
							busMsg["data"] = data["data"];
						foreach(BSubscription sub; subs) {
							foreach(string seq, WebSocket s; sub.subscribers) {
								if(s!=sock){
									busMsg["seqID"] = seq;
									busMsg["event"]["matchedTags"]=deserializeTags(sub.tags);
									s.send(busMsg.toString());
								}
							}
						}
						break;
					case "unsubscribe":
						
						break;
					case "exit":
						
						break;
					default:break;
				}
			}
		}
	}
	writeln("Connection closed! "~sock.request.clientAddress.to!string~" "~sock.request.headers["Sec-WebSocket-Key"]);
	for(int i=0;i<m_subs.length;i++){
		m_subs[i].removeSubscriber(sock);
	}
	m_socks.removeFromArray(sock);
	sock=null;
}
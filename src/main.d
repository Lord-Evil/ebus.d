module main;
//System Imports
import std.stdio;
import std.conv: to;
//import std.datetime;
import std.format;
import std.file;
import std.string;
import std.algorithm;
//Third-party Libs
import vibe.data.json;
import vibe.core.core : runApplication;
import vibe.core.log;
import vibe.http.router;
import vibe.http.server;
import vibe.utils.array;
import vibe.http.fileserver;
import vibe.http.websockets;


bool hasItem(Json[] haystack, string needle){
	for(int i=0; i<haystack.length; i++){
		if(haystack[i].type==Json.Type.string&&haystack[i].get!string==needle)
			return true;
	}
	return false;
}

/* Serialize tag of type Json to array of strings
   	Input tag can be
  		string -> [string]
		array (or array of arrays of strings) -> [strings, ...]
		dict -> [key!type.value, ...]
 	Result is array of strings
*/
string[] serializeTag(Json tag) {
	string[] res;
	switch (tag.type) {
		case Json.Type.string:
			res~="!"~tag.type.to!string~"."~tag.get!string;
			break;
		case Json.Type.int_:
		case Json.Type.bool_:
		case Json.Type.null_:
		case Json.Type.float_:
			res~="!"~tag.type.to!string~"."~tag.toString;
			break;
		case Json.Type.array:
			for(int i;i<tag.length;i++){
				Json subTag=tag[i];
				foreach(string stag;serializeTag(subTag)){
					res~="!array."~stag;
				}
			}
			break;
		case Json.Type.object:
			foreach(string key, Json value; tag){
				auto valueSerializedArray=serializeTag(value);
				foreach(string valueSerialized; valueSerializedArray){
					//writeln(value.type.to!string);
					res~="!object."~key~valueSerialized;
				}
			}
			break;
		default:
			throw new Exception("Bad tag type "~tag.type.to!string);
	}
	return res;
}

class BusGroup
{
	class Subscription
	{
		private:
		WebSocket[string] subscribers;
		public:
		protected string[] tags;
		this(Json _tags) {
			// serialization
			tags=serializeTag(_tags);
		}
		void addSubscriber(WebSocket s, string seq){
			subscribers[seq]=s;
		}
		void removeSubscriber(WebSocket s){
			string[] seqsToRemove;
			foreach(string seq, WebSocket sub; subscribers){
				if(sub==s)
					seqsToRemove~=seq;
			}
			foreach(string seq; seqsToRemove){
				subscribers.remove(seq);
			}
		}
		void removeSubscriber(string seq){
			subscribers.remove(seq);
		}
	}

	immutable string name;
	Subscription[] subs;//key is JSON array
	this(string _name){
		name=_name;
	}
	protected WebSocket[] members;//we don't really need this.. but good to be able to count
	// partial match search: tags in sub.tags
	Subscription[] findSubscriptionsForInvoke(Json tags){
		Subscription[] list;
		if(tags.type==Json.Type.object||tags.type==Json.Type.array){
			if(tags.length<1)
				return list;
		}else{
			//we really want to convert single value into array item
			Json t=Json.emptyArray;
			t~=tags;
			tags=t;
		}

		auto tagsSerialized = serializeTag(tags);
		writeln(tagsSerialized);
		foreach(Subscription sub; subs){
			bool fits=true;
			foreach(string tag; sub.tags){
				if(!tagsSerialized.canFind(tag)){
					fits=false;
					//writeln(tags," do not fit with ",tag);
					break;
				}
			}
			if(!fits) continue;
			list~=sub;
		}
		return list;
	}
	// full match search
	Subscription findSubscription(Json tags) {
		if(tags.type==Json.Type.object||tags.type==Json.Type.array){
			if(tags.length<1)
				return null;
		}else{
			//we really want to convert single value into array item
			Json t=Json.emptyArray;
			t~=tags;
			tags=t;
		}
		string[] tagsSerialized = serializeTag(tags);
		foreach(Subscription sub; subs) {
			if(tagsSerialized.length<1 || tagsSerialized.length!=sub.tags.length)
				continue;
			bool fits = true;
			foreach(string tag; tagsSerialized) {
				if (!sub.tags.canFind(tag)) {
					fits = false;
					break;
				}
			}
			if(!fits) continue;
			return sub;
		}
		return null;
	}
	Subscription Subscribe(Json tags, WebSocket subscriber, string seq){
		Subscription sub=findSubscription(tags);
		if(sub !is null)
			sub.addSubscriber(subscriber, seq);
		else{
			if(tags.type!=Json.Type.object||tags.type!=Json.Type.array){
				//we really want to convert single value into array item
				Json t=Json.emptyArray;
				t~=tags;
				tags=t;
			}
			sub=new Subscription(tags);
			sub.addSubscriber(subscriber, seq);
			subs~=sub;
		}
		return sub;
	}

}

BusGroup[string] groups;

void main(){
	Json config=parseJsonString(cast(string)std.file.read("config.json"));
	logInfo("Server started!");
	auto router = new URLRouter;
	router
		.post("/push/:group/:action",&httpEventHandler)
		.get("/ws",handleWebSockets(&handleConn));

	auto settings = new HTTPServerSettings;
	settings.port = config["port"].get!ushort;
	settings.sessionStore = new MemorySessionStore;
	settings.bindAddresses =  [config["bind"].get!string];
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
		groups[group_name] = new BusGroup(group_name);
		//writeln("Created new group "~group_name);
	}else{
		//writeln("Existing group "~group_name);
	}
	switch(action){
		case "invoke":
			Json data=req.json;
			writeln(data);

			Json busMsg=Json.emptyObject;
			busMsg["group"] = group_name;
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

			foreach(BusGroup.Subscription sub; subs) {
				foreach(string seq, WebSocket s; sub.subscribers) {
					busMsg["seqID"] = seq;
					busMsg["event"]["matchedTags"]="TODO";  //deSerializeTag(sub.tags);
					s.send(busMsg.toString());
				}
			}
			break;
		default:break;
	}
	res.writeJsonBody(["status":"OK"]);
}
WebSocket[] m_socks;
void handleConn(scope WebSocket sock)
{
	logInfo("Incomming connection! "~sock.request.clientAddress.to!string~" "~sock.request.headers["Sec-WebSocket-Key"]);
	//logInfo(sock.request.headers);
	m_socks~=sock;
	BusGroup.Subscription[] m_subs;
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
			if (group_name !in groups){
				groups[group_name] = new BusGroup(group_name);
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
						Json tags = data["tags"];
						writeln("Invoke tags "~tags.toString());
						auto subs=groups[group_name].findSubscriptionsForInvoke(tags);
						if(subs.length < 1) break;
						Json busMsg=Json.emptyObject;
						busMsg["group"] = group_name;
						busMsg["action"] = "invoke";
						busMsg["event"] = Json.emptyObject;
						busMsg["event"]["tags"]=tags;
						if(data["data"].type != Json.Type.undefined)
							busMsg["data"] = data["data"];
						foreach(BusGroup.Subscription sub; subs) {
							foreach(string seq, WebSocket s; sub.subscribers) {
								if(s!=sock){
									busMsg["seqID"] = seq;
									busMsg["event"]["matchedTags"]="TODO";  //deSerializeTag(sub.tags);
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
	logInfo("Connection closed! "~sock.request.clientAddress.to!string~" "~sock.request.headers["Sec-WebSocket-Key"]);
	for(int i=0;i<m_subs.length;i++){
		m_subs[i].removeSubscriber(sock);
	}
	m_socks.removeFromArray(sock);
	sock=null;
}
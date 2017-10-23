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


// TODO
// join
// subcribe
// invoke
// socks queue

/*{
	groupA: {
		subscriptions: [
		  {
		    tags,
		    seqID,
		    WebSocket
		  },
		  ...
		],
	},
	groupB: ...
}
*/


class BusGroup
{
	class Subscription
	{
	private:
		WebSocket[string] subscribers;
	public:
		protected Json tags;
		this(Json _tags){
			tags=_tags;
		}
		void addSubscriber(WebSocket s,string seq){
			if(seq !in subscribers)
				subscribers[seq]=s;
		}
		void removeSubscriber(WebSocket s){
			string[] keysToRemove;
			foreach(string key,WebSocket sub;subscribers){
				if(sub==s)
					keysToRemove~=key;
			}
			foreach(string key;keysToRemove){
				subscribers.remove(key);
			}
		}
		void removeSubscriber(string seq){
			subscribers.remove(seq);
		}
	}

	immutable string name;
	Subscription[] subs;//key is JSON array
	this(string _name){
		name=name;
	}
	void addSubscription(Json tags, WebSocket subscriber, string seq){
		foreach(Subscription sub; subs){
			bool fits=true;
			if(tags.length!=sub.tags.length||tags.length==0)
				continue;
			foreach(Json tag;tags){
				switch (tag.type) {
					case Json.Type.string:

						break;
					case Json.Type.array:
						break;
					case Json.Type.object:
						break;
					case Json.Type.undefined:
					case Json.Type.null_:
					case Json.Type.bool_:
					case Json.Type.int_:
					case Json.Type.bigInt:
					case Json.Type.float_:
					default:
						continue;//might need to remove bad tag
				}
			}
		}
	}

}

Json groups;

void main(){
	//can not initialize objects in global
	groups = Json.emptyObject;

	Json config=parseJsonString(cast(string)std.file.read("config.json"));
	logInfo("Server started!");
	auto router = new URLRouter;
	router
		.get("/*",serveStaticFiles("./public"))
		.get("/ws",handleWebSockets(&handleConn));

	auto settings = new HTTPServerSettings;
	settings.port = config["port"].get!ushort;
	settings.sessionStore = new MemorySessionStore;
	settings.bindAddresses =  [config["bind"].get!string];
	settings.useCompressionIfPossible=true;
	//settings.errorPageHandler = toDelegate(&errorPage);
	listenHTTP(settings, router);
	runApplication();
}
WebSocket[] m_socks;
void handleConn(scope WebSocket sock)
{
	logInfo("Incomming connection! "~sock.request.clientAddress.to!string~" "~sock.request.headers["Sec-WebSocket-Key"]);
	//logInfo(sock.request.headers);
	m_socks~=sock;
	while (sock.waitForData()) {
		string msg = sock.receiveText();
		Json data;
		try{
			data = parseJsonString(msg);
			writeln(data);
		}catch(Exception e){
			continue;
		}

		// TODO: add data in queue and do stuff in other place
		if(data["group"].type!=Json.Type.undefined){
			string group_name = data["group"].get!string;
			if (groups[group_name].type==Json.Type.undefined){
				groups[group_name] = Json.emptyObject;
				writeln("Created new group "~group_name);
			}else{
				writeln("Existing group "~group_name);
			}
			if(data["data"]["action"].type!=Json.Type.undefined){
				string action = data["data"]["action"].get!string;
				switch(action){
					case "join":
						
						break;
					case "subscribe":
						
						break;
					case "request":
						
						break;
					case "chat":
						
						break;

					case "invoke":
						
						break;
					case "unsubscribe":
						
						break;
					case "exit":
						
						break;
					default:break;

				}
			}
		}
		/*
		switch (data["data"]["action"].get!string)
		{
			case "join":
			{
				logInfo("Join to group "~group_name~"! "~sock.request.clientAddress.to!string~" "~sock.request.headers["Sec-WebSocket-Key"]);
				break;
			}
			case "subscribe":
			{
				Json sub=Json.emptyObject;
				sub["tags"] = data["tags"];
				sub["seqID"] = data["seq"];
				// can't implist asign websocket to Json field, so take it main data or try serialize to string
				//auto webSocketData = Json.emptyObject;
				//webSocketData["address"] = sock.request.clientAddress.to!string;
				//webSocketData["sec_key"] = sock.request.headers["Sec-WebSocket-Key"];
				sub["WebSocket"] = to!string(sock);  //webSocketData;
				groups[group_name]["subscriptions"] ~= sub;
				// send res
				sock.send(data["seq"].get!string);
				logInfo("Subscribe in group "~group_name~" on tags "~"<tags array>"~"!"~sock.request.clientAddress.to!string~" "~sock.request.headers["Sec-WebSocket-Key"]);
				break;
			}
			case "invoke":
			{
				// TODO
				auto events = null;
				logInfo("Invoke in group "~group_name~" events "~"<events array>"~"!"~sock.request.clientAddress.to!string~" "~sock.request.headers["Sec-WebSocket-Key"]);
				break;
			}
			default :
				throw new Exception("Not implemented action type!");
		}

		//sock.send("Shut up and listen!");
		//Json data=Json.emptyObject;
		//data["msg"]=msg;
		//string[] clients;
		//foreach(WebSocket s_sock;m_socks){
		//		if(s_sock!=sock)
		//			s_sock.send(data.toString());
		//}
		*/
	}
	logInfo("Connection closed! "~sock.request.clientAddress.to!string~" "~sock.request.headers["Sec-WebSocket-Key"]);

	m_socks.removeFromArray(sock);
	sock=null;
}
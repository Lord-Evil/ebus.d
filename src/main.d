module main;
//System Imports
import std.stdio;
import std.conv: to;
//import std.datetime;
import std.format;
import std.file;
import std.string;
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



void main(){
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
Json groups = Json.emptyObject;
void handleConn(scope WebSocket sock)
{
	logInfo("Incomming connection! "~sock.request.clientAddress.to!string~" "~sock.request.headers["Sec-WebSocket-Key"]);
	//logInfo(sock.request.headers);
	m_socks~=sock;
	while (sock.waitForData()) {
		auto msg = sock.receiveText();
		auto data = parseJsonString(msg);

		// TODO: add data in queue and do stuff in other place

		auto group_name = data["group"].get!string;
		if (groups[group_name]) groups[group_name] = Json.emptyObject;
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
	}
	logInfo("Connection closed! "~sock.request.clientAddress.to!string~" "~sock.request.headers["Sec-WebSocket-Key"]);

	m_socks.removeFromArray(sock);
	sock=null;
}
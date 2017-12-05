module main;
//our modules
import imports;
import Bus;
import butils;


alias void function(int) sighandler_t;
extern (C) sighandler_t signal(int signum, sighandler_t handler);


/* Format of client messages data:
	{
		"group": <string name>,
		"action": "subscribe/invoke/etc",
		["seq": "ad19690109566ab3",]
		["tags": Json,]
		["data": Json]
	}
*/
// Maybe need do this in other place (in some class etc)
void socketsWorker(SocketWithMessage socketWithMessage) {
	if (socketWithMessage is null) return;
	WebSocket sock = socketWithMessage.socket;
	string msg = socketWithMessage.message;
	writeln(msg);
	Json data = parseJsonString(msg);
	string seqID=data["seq"].get!string;
	data = parseJsonString(msg);
	writeln(data);
	seqID=data["seq"].get!string;
	if(data["group"].type!=Json.Type.undefined){
		string group_name = data["group"].get!string;
		synchronized (groups_lock) {
			if (group_name !in groups){
				groups[group_name] = cast(shared)(new BGroup(group_name));
				//writeln("Created new group "~group_name);
			}else{
				//writeln("Existing group "~group_name);
			}
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
					synchronized (m_subs_lock) {
						synchronized (groups_lock)
						{
							if(tags.length>0) {
								m_subs~=cast(shared)((cast(BGroup)groups[group_name]).Subscribe(tags, sock, seqID));
							}
						}
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
					synchronized (groups_lock) {
						auto subs=(cast(Bus.BGroup)groups[group_name]).findSubscriptionsForInvoke(tags);
						if(subs.length < 1) break;
						Json busMsg=Json.emptyObject;
						busMsg["group"] = group_name;
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
void threadWorker(Tid parentId) {
    bool canceled = false;
    writeln("Starting ", thisTid, "...");
    while (!canceled) {
		receive(
			(immutable SocketWithMessage sm) {
				socketsWorker(cast(SocketWithMessage) sm);
			},
			// stop threads and send msg about it to parent thread
	       	(CancelMessage m) {
				writeln("Stopping ", thisTid, "...");
				send(parentId, CancelAckMessage());
				canceled = true;
	        }
		);
    };
}


WebSocket[] m_socks;
Tid[] threadPool;
int currentThreadNumber = 0;
// number of worker threads to msg passing, default = count of CPUs
int threadCount;
shared BGroup[string] groups;
shared Bus.BSubscription[] m_subs;
shared(Lock) m_subs_lock;
shared(Lock) groups_lock;


void main(){
	m_subs_lock = new shared(Lock)();
	groups_lock = new shared(Lock)();

	disableDefaultSignalHandlers();
	signal(2, &shutDown);
	// generate worker threads threadPool
	threadCount = cast(int)workerThreadCount;
	for(size_t i=0; i < threadCount; i++){
		auto threadId = spawn(&threadWorker, thisTid);
		threadPool ~= threadId;
	}
	string ver = import("version.txt").strip();
	writeln("Starting EBus build "~ver);
	Json config=parseJsonString(cast(string)std.file.read("config.json"));
	writeln("Server started!");
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
	writeln("Stopping thread workers...");
	foreach(ref tid; threadPool) {
        send(tid, CancelMessage());
    }
	foreach(ref tid; threadPool) {
        receiveOnly!CancelAckMessage;
        writeln("Received CancelAckMessage!");
    }
}
void httpEventHandler(HTTPServerRequest req, HTTPServerResponse res){
	string group_name=req.params["group"];
	string action=req.params["action"];
	synchronized (groups_lock) {
		if (group_name !in groups){
			groups[group_name] = cast(shared)(new BGroup(group_name));
			//writeln("Created new group "~group_name);
		}else{
			//writeln("Existing group "~group_name);
		}
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
			synchronized (groups_lock) {
				auto subs=(cast(BGroup)groups[group_name]).findSubscriptionsForInvoke(tags);
				if(subs.length < 1) break;

				foreach(Bus.BSubscription sub; subs) {
					foreach(string seq, WebSocket s; sub.subscribers) {
						busMsg["seqID"] = seq;
						busMsg["event"]["matchedTags"]=deserializeTags(sub.tags);
						s.send(busMsg.toString());
					}
				}
			}
			break;
		default:break;
	}
	res.writeJsonBody(["status":"OK"]);
}
void handleConn(scope WebSocket sock)
{
	writeln("Incomming connection! "~sock.request.clientAddress.to!string~" "~sock.request.headers["Sec-WebSocket-Key"]);
	//writeln(sock.request.headers);
	m_socks~=sock;
	while (sock.waitForData()) {
		string sockMessage = sock.receiveText();
		try{
			auto sm = new immutable SocketWithMessage(sock, sockMessage);
			send(threadPool[currentThreadNumber], sm);
			currentThreadNumber += 1;
			currentThreadNumber = currentThreadNumber % threadCount;
		}catch(Exception e){
			writeln("#####ERROR####");
			writeln(e.msg);
			writeln(sockMessage);
			writeln("##############");
			continue;
		}
	}
	writeln("Connection closed! "~sock.request.clientAddress.to!string~" "~sock.request.headers["Sec-WebSocket-Key"]);
	synchronized (m_subs_lock) {
		for(int i=0;i<m_subs.length;i++){
			(cast(BSubscription)m_subs[i]).removeSubscriber(sock);
		}
	}
	m_socks.removeFromArray(sock);
	sock=null;
}
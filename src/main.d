module main;
//our modules
import imports;
import Bus;
import butils;

import std.datetime.systime;
import std.container : SList;
import std.algorithm : canFind;
import core.sync.mutex : Mutex;

BGroup[string] groups;
Json config;
Mutex groupsMutex;
bool debugLog = false;

void main()
{
	string ver = import("version.txt").strip();
	writeln("// Starting EBus build " ~ ver);
	config = parseJsonString(cast(string) std.file.read("config.json"));

	// Validate required config fields
	if (config["port"].type == Json.Type.undefined)
		throw new Exception("Missing 'port' in config.json");
	if (config["bind"].type == Json.Type.undefined)
		throw new Exception("Missing 'bind' in config.json");
	if (config["auth"].type == Json.Type.undefined)
		throw new Exception("Missing 'auth' in config.json");
	if (config["debug"].type == Json.Type.undefined)
		debugLog = false;
	else
		debugLog = config["debug"].get!bool;

	groupsMutex = new Mutex();
	writeln("// Server started!");
	auto router = new URLRouter;
	router
		.post("/push/:group/:action", &httpEventHandler)
		.get("/ws", handleWebSockets(&handleConn));

	auto settings = new HTTPServerSettings;
	settings.port = config["port"].get!ushort;
	settings.sessionStore = new MemorySessionStore;
	settings.bindAddresses = [config["bind"].get!string];
	settings.useCompressionIfPossible = true;
	settings.serverString = "ebus.d/1.0.0";
	//settings.errorPageHandler = toDelegate(&errorPage);
	auto listener = listenHTTP(settings, router);
	scope (exit)
	{
		writeln("// Shutting down gracefully...");
		listener.stopListening();
		// Close all WebSocket connections
		synchronized (groupsMutex)
		{
			foreach (group_name, group; groups)
			{
				writeln("// Closing connections in group: " ~ group_name);
			}
			groups.clear();
		}
		writeln("// Shutdown complete!");
	}
	runApplication();
}

void httpEventHandler(HTTPServerRequest req, HTTPServerResponse res)
{
	string group_name = req.params["group"];
	string action = req.params["action"];

	synchronized (groupsMutex)
	{
		if (group_name !in groups)
		{
			groups[group_name] = new BGroup(group_name);
			//writeln("Created new group "~group_name);
		}
		else
		{
			//writeln("Existing group "~group_name);
		}
	}

	switch (action)
	{
	case "invoke":
		SysTime today = Clock.currTime();
		if(debugLog){
			writeln("// Invoke for group " ~ group_name);
			writeln("// ", today);
		}
		Json data = req.json;
		if(debugLog) writeln(data);

		Json busMsg = Json.emptyObject;
		if (config["auth"].get!bool)
		{
			string* group = (group_name in reGroup);
			if (group != null)
				busMsg["group"] = *group;
		}
		else
		{
			busMsg["group"] = group_name;
		}
		busMsg["action"] = "invoke";
		busMsg["event"] = Json.emptyObject;
		Json tags;
		if (data.type == Json.Type.object && data["tags"].type != Json.Type.undefined)
		{
			tags = data["tags"];
			busMsg["event"]["tags"] = tags;
			if (data["data"].type != Json.Type.undefined)
				busMsg["data"] = data["data"];
		}
		else
		{
			tags = data;
			busMsg["event"]["tags"] = tags;
		}

		Bus.BSubscription[] subscriptions;
		synchronized (groupsMutex)
		{
			//writeln("Invoke tags "~tags.toString());
			subscriptions = groups[group_name].findSubscriptionsForInvoke(tags);
		}

		foreach (Bus.BSubscription subscription; subscriptions)
		{
			WebSocket[] badSocks;
			foreach (string seq, WebSocket s; subscription.subscribers)
			{
				busMsg["seqID"] = seq;
				busMsg["event"]["matchedTags"] = deserializeTags(subscription.tags);
				try
				{
					s.send(busMsg.toString());
				}
				catch (Exception e)
				{
					writeln("// !!!!!The most unexpected thing happened: " ~ e.msg);
					badSocks ~= s;
					s.close();
				}
			}

			synchronized (groupsMutex)
			{
				foreach (WebSocket s; badSocks)
				{
					subscription.removeSubscriber(s);
					if (group_name in groups)
					{
						groups[group_name].removeSubscriber(s);
					}
				}
			}
		}

		ulong counter = 0;
		synchronized (groupsMutex)
		{
			if (group_name in groups)
			{
				counter = groups[group_name].totalSubscribers;
			}
		}
		res.writeJsonBody(Json([
				"status": Json("OK"),
				"subscribers": Json(counter)
			]));
		return;
	default:
		break;
	}
	res.writeJsonBody(["status": "OK"]);
}

//auto m_socks=SList!WebSocket(); // Unused - commented out

string[string] reGroup;

void handleConn(scope WebSocket sock)
{
	if(debugLog)
		writeln("// Websocket: Incoming connection! " ~ sock.request.clientAddress.to!string ~ " " ~ sock
			.request.headers["Sec-WebSocket-Key"]);
	//writeln(sock.request.headers);
	//m_socks.insert(sock); // Commented out - unused
	Bus.BSubscription[] m_subs;
	string[] m_groups; // Track groups this connection subscribed to
	try
	{
		while (sock.waitForData())
		{
			string msg = sock.receiveText();
			Json data;
			string seqID;
			try
			{
				/* Format: 
					{
						"group": <string name>,
						"action": "subscribe/invoke/etc",
						["seq": "ad19690109566ab3",]
						["tags": Json,]
						["data": Json]
				*/
				data = parseJsonString(msg);
				if (data["alive"].type != Json.Type.undefined)
					continue;
				if(debugLog) writeln("// Websocket: ");
				if(debugLog) writeln(data);
				seqID = data["seq"].get!string;
			}
			catch (Exception e)
			{
				writeln("// Websocket: #####ERROR####");
				writeln(e.msg);
				writeln(msg);
				writeln("// Websocket: ##############");
				continue;
			}

			// TODO: add data in queue and do stuff in other place
			if (data["group"].type != Json.Type.undefined)
			{
				string group_name = data["group"].get!string;
				if (config["auth"].get!bool)
				{
					string rname = resolveGroup(group_name, config["authUrl"].get!string, config["authKey"]
							.get!string);
					if (rname.length > 1)
					{
						reGroup[rname] = group_name;
						group_name = rname;
					}
				}

				synchronized (groupsMutex)
				{
					if (group_name !in groups)
					{
						groups[group_name] = new BGroup(group_name);
						//writeln("Created new group "~group_name);
					}
					else
					{
						//writeln("Existing group "~group_name);
					}
				}

				if (data["action"].type != Json.Type.undefined)
				{
					string action = data["action"].get!string;
					switch (action)
					{
					case "join":
						//no real purpose, could be used for member count or auth (via tokens etc)
						if(debugLog) writeln("// Websocket: Join group " ~ group_name);
						break;
					case "subscribe":
						if (data["tags"].type == Json.Type.undefined)
							break;
						Json tags = data["tags"];
						if (tags.length > 0)
						{
							synchronized (groupsMutex)
							{
								m_subs ~= groups[group_name].Subscribe(tags, sock, seqID);
							}
							// Track this group for cleanup on disconnect
							if (!m_groups.canFind(group_name))
								m_groups ~= group_name;
						}
						if(debugLog) writeln("// Websocket: Subscribe for tags " ~ tags.toString());
						break;
					case "request":
						//TODO - to implement
						break;
					case "chat":
						//TODO - to implement
						break;

					case "invoke":
						if (data["tags"].type == Json.Type.undefined)
							break;
						Json tags = data["tags"];
						if(debugLog) writeln("// Websocket: Invoke tags " ~ tags.toString());

						BSubscription[] subs;
						synchronized (groupsMutex)
						{
							subs = groups[group_name].findSubscriptionsForInvoke(tags);
						}
						if (subs.length < 1)
							break;

						Json busMsg = Json.emptyObject;
						if (config["auth"].get!bool)
						{
							string* group = (group_name in reGroup);
							if (group != null)
								busMsg["group"] = *group;
						}
						else
						{
							busMsg["group"] = group_name;
						}
						busMsg["action"] = "invoke";
						busMsg["event"] = Json.emptyObject;
						busMsg["event"]["tags"] = tags;
						if (data["data"].type != Json.Type.undefined)
							busMsg["data"] = data["data"];

						foreach (BSubscription sub; subs)
						{
							WebSocket[] badSocks;
							foreach (string seq, WebSocket s; sub.subscribers)
							{
								if (s != sock)
								{
									busMsg["seqID"] = seq;
									busMsg["event"]["matchedTags"] = deserializeTags(sub.tags);
									try
									{
										s.send(busMsg.toString());
									}
									catch (Exception e)
									{
										writeln("// Websocket: Seems like websocket has died: " ~ s.request
												.clientAddress.to!string ~ " " ~ s.request
												.headers["Sec-WebSocket-Key"]);
										badSocks ~= s;
										s.close();
									}
								}
							}
							// Clean up dead sockets
							synchronized (groupsMutex)
							{
								foreach (WebSocket s; badSocks)
								{
									sub.removeSubscriber(s);
									if (group_name in groups)
									{
										groups[group_name].removeSubscriber(s);
									}
								}
							}
						}
						break;
					case "unsubscribe":
						//TODO - to implement
						break;
					case "exit":
						//TODO - to implement
						break;
					default:
						break;
					}
				}
			}
		}
	}
	catch (Exception e)
	{
		writeln("// Websocket: !!!!!The most unexpected thing happened: " ~ e.msg);
	}
	if(debugLog) writeln("// Websocket: Connection closed! " ~ sock.request.clientAddress.to!string ~ " " ~ sock
			.request.headers["Sec-WebSocket-Key"]);

	// Remove subscriber from all subscriptions
	foreach (sub; m_subs)
	{
		sub.removeSubscriber(sock);
	}

	// Remove subscriber from all groups it was part of
	synchronized (groupsMutex)
	{
		foreach (string group_name; m_groups)
		{
			if (group_name in groups)
			{
				groups[group_name].removeSubscriber(sock);

				// Clean up empty groups (memory leak fix)
				if (groups[group_name].isEmpty())
				{
					groups.remove(group_name);
					if(debugLog) writeln("// Cleaned up empty group: " ~ group_name);

					// Clean up reGroup mapping (memory leak fix)
					if (group_name in reGroup)
					{
						reGroup.remove(group_name);
					}
				}
			}
		}
	}

	//m_socks.linearRemoveElement(sock); // Commented out - m_socks is unused
	sock = null;
}

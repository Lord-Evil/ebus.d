#!/usr/bin/env node
var WebSocket=require("websocket").w3cwebsocket;
var EBus=require("../../libs/js/ebus");
EBus.reWS(WebSocket);
var wURL="ws://localhost:4445/ws"
function chatMessage(event,data,chat){
	console.log("<<"+data.from+":", data.text);
}
function chatEvent(event,data,chat){
	if(event.tags=="memberEnter")
		console.log("Member",data.name, "entered the chat");
	if(event.tags=="memberExit")
		console.log("Member",data.name, "left the chat");
	
}
let username="NodeJS WebSocket Client";
var con=EBus.connect(wURL, ()=>{
	var sg=con.joinGroup("chat");
	sg.subscribe("message",chatMessage);
	sg.subscribe("memberEnter",chatEvent);
  	sg.subscribe("memberExit",chatEvent);
	sg.invoke("memberEnter",{name:username});
	sg.invoke("message",{text:"Hello all, from console!", from:username});
	process.on('SIGTERM', function () {
		sg.invoke("memberExit",{name:username});
		process.exit(0);
	});
	process.on('SIGINT', function () {
		sg.invoke("memberExit",{name:username});
		process.exit(0);
	});
	/*
sg.invoke("tag1");
sg.invoke(["tag1"]);
sg.invoke(["tag1","tag2"],{"message":"Work time!"});
	*/
});

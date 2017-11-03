var WebSocket=require("websocket").w3cwebsocket;
var EBus=require("../../libs/js/ebus");
EBus.reWS(WebSocket);
var wURL="ws://localhost:4445/ws"
function chatMessage(event,data,chat){
	console.log("<<"+data.from+":", data.text);
}
let username="NodeJS WebSocket Client";
var con=EBus.connect(wURL, ()=>{
	var sg=con.joinGroup("chat");
	sg.subscribe("message",chatMessage);
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

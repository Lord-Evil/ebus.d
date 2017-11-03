var WebSocket=require("websocket").w3cwebsocket;
var EBus=require("../../public/ebus");
EBus.reWS(WebSocket);
var wURL="ws://localhost:4445/ws"

function subscription1(event,data,chat){
	console.log("Invoked", data?"with message: "+data.message:"");
}

var con=EBus.connect(wURL, ()=>{
	var sg=con.joinGroup("test");
	sg.subscribe("tag1",subscription1);
	sg.invoke("tag1",{message:"NodeClient is here!"});
	/*
sg.invoke("tag1");
sg.invoke(["tag1"]);
sg.invoke(["tag1","tag2"],{"message":"Work time!"});
	*/
});

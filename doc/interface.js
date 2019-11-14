WebSocket

//Connection
var conn=EBus.connect("http://hub.mega-bot.com/",connecHandler);
//Join a sertain event group; event if it doesn't exist
var group = conn.joinGroup("MegaChat");
group.exit();

//Subscription, server will reply with subscription ID that will be stored in a subscription's dictionary along with subscription key and handler reference
///Single event tag -- string type
group.subscribe("chatMessage",chatHandler);
///Multiple event tags (AND) -- string type
group.subscribe(["chatMessage","privateMessage"],chatHandler);
///Object type tag
group.subscribe({fsm:"206a8a98a222"},robotEventsHandler);
group.subscribe({fsm:"206a8a98a222",node:"9e9c1bbc"},robotEventsHandler);

//Event invocation
///Simple string tag
group.invoke({action:"Fireworks"});
///Single tag -- string; with data sideload
group.invoke("chatMessage",{...});
///Mixed type tags array with data sideload
group.invoke(["chatMessage","privateMessage",{messageTo:"Sexy Boy N1"}],{...});

//Requests
//***same as invoke, but server will respon with request ID and on reply supply (data,requestID)
group.request({action:"listPeople"},{/* optional sideload or null/undefined */},(data,chat)=>{
	//chat can be reused to reply multiple times
});

//Unsibscribe
group.drop("chatMessage",chatHandler);

//Broadcasts
///Send to all listeners
group.shout({...});
///Subscribe for the broadcast
group.listenAll((data)=>{

});

//Excemple event handler
function chatHandler(event,data,chat){
	/*
		event:
		{
			matchedTags -- criteria that was used to match a particular event; might be needed in case of multiple possible matches
							//Please, NOTE: in case you have subsribed to basic type like string, e.g. "message", it will be converted into an array containing your subscription, ["message"]
			tags -- the actial full event tags invoked
		}
		data -- sideload if present
		chat -- chat object if it requires/expects the reply;
		e.g.:
	*/
	chat.reply({...},(data,chat)=>{
		//this can establish one to one continiuos chat
		
		//to forbid any further replies
		chat.final({...});
	});
}
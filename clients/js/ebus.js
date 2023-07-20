//Utils
function guid() {
	function s4() {
		return Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(1);
	}
	return s4() + s4() + s4() + s4();
}
//End Utils
class ESubscription{
	constructor(tags,callback){
		this.tags=tags;
		this.callback=callback;
	}
}
function EGroup(name,msgInt,exitCbk){
	var sendMessage=msgInt;
	var exitGroup=exitCbk;
	var name=name;
	var subscriptions={};
	function findSubscription(tags,callback){
		Object.keys(subscriptions, (key)=>{
			let sub=subscriptions[key];
			if(sub.tags==tags&&sub.callback==callback)
				return key;
		});
		return null;
	}
	class EGroup
	{
		constructor()
		{
			sendMessage({action:"join"});
		}
		get name(){
			return name;
		}
		getSubCallback(subID){
			if(subID in subscriptions) return subscriptions[subID].callback;
			return null;
		}
		subscribe(tags,callback)
		{
			var subID=findSubscription(tags,callback);
			if(subID){
				let e=new Error("Already subscribed!");
				e.name="subscribe";
				throw e;	
			} 
			var sub=new ESubscription(tags,callback);
			subID=sendMessage({action:"subscribe",tags:tags});
			subscriptions[subID]=sub;
		}
		invoke(tags,data)
		{
			if(data)
				sendMessage({action:"invoke",tags:tags,data:data});
			else
				sendMessage({action:"invoke",tags:tags});
		}
		request(tags,data,callback)
		{
			//might be also over http same as subscribe for the same reason
		}
		drop(tags,callback)
		{
			var subID=findSubscription(tags,callback);
			if(!subID){
				let e=new Error("No such subscription!");
				e.name="drop";
				throw e;	
			}
			sendMessage({action:"unsubscribe",seq:subID});
			delete subscriptions[subID];

		}
		shout(data)
		{
			if(data)
				invoke("broadcast",data);
			else{
				let e=new Error("No data to shout");
				e.name="shout";
				throw e;
			}
		}
		listenAll(callback)
		{
			subscribe("broadcast",callback);
		}
		exit()
		{
			exitGroup();
			sendMessage({action:"exit"});
		}
	}
	return new EGroup();
}
function EConnection(url,onConnect){
	var eCon;
	var _wsConn = new WebSocket(url);
	var _groups={};
	var keepAlive;
	function _inMessage(data){
		/*
			{
				group:"sex",
				action:"invoke",
				event:{
					matchedTags:["tag1"],
					tags:["tag1","tag2"]
				}
				data:{},
				seqID:"96b2facc756ee65a"
			}
		*/
		if(data.group && data.group in _groups){
			let group=_groups[data.group];
			if(data)
			switch(data.action){
				case "invoke":
					let callback=group.getSubCallback(data.seqID);
					if(callback){
						var chat;
						callback(data.event,data.data,chat);
					}
					break;
				default:
					console.log("Unknown action: "+data.action);
					break;
			}
		}
	}
	function sendMessage(data){
		_wsConn.send(JSON.stringify(data));
	}
	class EConnection{
		constructor(onConnect)
		{
			let keepAlive;
			_wsConn.onopen=(e)=>{
				console.log("Connection established!");
				//This is mainly needed for the web browsers, coz they tend to close "inactive" connection
				keepAlive = setInterval(()=>{
					_wsConn.send('{"alive":true}');
				},10000);
				if(onConnect)onConnect(this);
			};
			_wsConn.onmessage=(e)=>{
				try{
					_inMessage(JSON.parse(e.data));
				}catch(er){
					console.log("Server sent invalid JSON: "+e.data)
				}
			};
			_wsConn.onclose=(e)=>{
				console.log("Connection closed!");
				clearInterval(keepAlive);
			};
		}
		get groups(){
			let groupList={};
			Object.keys(_groups).forEach((k)=>{
				groupList[k]=_groups[k];
			});
			return groupList;
		}
		joinGroup(gName)
		{
			if(gName in _groups){
				let e=new Error("Aleady joined!");
				e.name="joinGroup";
				throw e;
			}else{
				var group=new EGroup(gName,(data)=>{
					var seqID=guid();
					let d = {group:gName, seq:seqID};
					Object.assign(d, data);
					sendMessage(d);
					return seqID;
				},()=>{
					if(gName in _groups){
						delete _groups[gName];
					}else{
						let e=new Error("Already exited!");
						e.name="exitGroup";
						throw e;
					}
				});
				_groups[gName]=group;
				console.log("Joined group \""+gName+"\"");
				return group;
			}
		}
		close(){
			_wsConn.close();
		}
	}
	eCon=new EConnection(onConnect);
	return eCon;
}

class EBus{
	static connect(url,onConnect){
		try{
			return new EConnection(url,onConnect);
		}catch(e){
			console.log(e.name+": "+e.message);
			return null;
		}
	}
	static reWS(ws){
		if(typeof global!="undefined")
			global.WebSocket=ws;
	}
}
if(typeof module!="undefined")
	module.exports=EBus


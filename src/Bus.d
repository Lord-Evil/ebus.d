module Bus;
//our modules
import imports;
import butils;


class BSubscription
{
public:
	WebSocket[string] subscribers;
	string[] tags;
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

class BGroup
{
	immutable string name;
	BSubscription[] subs;//key is JSON array
	this(string _name){
		name=_name;
	}
	protected WebSocket[] members;//we don't really need this.. but good to be able to count
	// partial match search: tags in sub.tags
	BSubscription[] findSubscriptionsForInvoke(Json tags){
		BSubscription[] list;
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
		foreach(BSubscription sub; subs){
			bool fits=true;
			foreach(string tag; sub.tags){
				if(!tagsSerialized.canFind(tag)){
					fits=false;
					break;
				}
			}
			if(!fits) continue;
			list~=sub;
		}
		return list;
	}
	// full match search
	BSubscription findSubscription(Json tags) {
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
		foreach(BSubscription sub; subs) {
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
	BSubscription Subscribe(Json tags, WebSocket subscriber, string seq){
		BSubscription sub=findSubscription(tags);
		if(sub !is null)
			sub.addSubscriber(subscriber, seq);
		else{
			if(tags.type!=Json.Type.object&&tags.type!=Json.Type.array){
				//we really want to convert single value into array item
				Json t=Json.emptyArray;
				t~=tags;
				tags=t;
			}
			sub=new BSubscription(tags);
			sub.addSubscriber(subscriber, seq);
			subs~=sub;
		}
		return sub;
	}

}

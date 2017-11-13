module butils;//Bus Utils, yeah? Yeah?!
import imports;

bool hasItem(Json[] haystack, string needle){
	for(int i=0; i<haystack.length; i++){
		if(haystack[i].type==Json.Type.string&&haystack[i].get!string==needle)
			return true;
	}
	return false;
}

/* Serialize tag of type Json to array of strings
   	Input tag can be
  		string -> [string]
		array (or array of arrays of strings) -> [strings, ...]
		dict -> [key!type.value, ...]
 	Result is array of strings
*/
string[] serializeTag(Json tag) {
	string[] res;
	switch (tag.type) {
		case Json.Type.string:
			res~="!"~tag.type.to!string~"."~tag.get!string;
			break;
		case Json.Type.int_:
		case Json.Type.bool_:
		case Json.Type.null_:
		case Json.Type.float_:
			res~="!"~tag.type.to!string~"."~tag.toString;
			break;
		case Json.Type.array:
			for(int i;i<tag.length;i++){
				Json subTag=tag[i];
				foreach(string stag;serializeTag(subTag)){
					res~="!array."~stag;
				}
			}
			break;
		case Json.Type.object:
			foreach(string key, Json value; tag){
				auto valueSerializedArray=serializeTag(value);
				foreach(string valueSerialized; valueSerializedArray){
					//writeln(value.type.to!string);
					res~="!object."~key~valueSerialized;
				}
			}
			break;
		default:
			throw new Exception("Bad tag type "~tag.type.to!string);
	}
	return res;
}

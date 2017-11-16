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
					res~="!object."~key~valueSerialized;
				}
			}
			break;
		default:
			throw new Exception("Bad tag type "~tag.type.to!string);
	}
	return res;
}
Json stringsToJson(string[] list){
	Json jlist=Json.emptyArray;
	foreach(string s; list){
		jlist~=s;
	}
	return jlist;
}
Json deserializeTags(string[] tags){
	//tags could result in object or array
	if(tags.length>0){
		if(tags[0].indexOf("!array.")==0){
			Json result=Json.emptyArray;
			string[] depthA;
			string[] depthO;
			foreach(string item; tags){
				string[] chunks=item.split(".");
				switch(chunks[1][1..$]){
					case "string":
						//в чистом виде сплит не очень, т.к. строковые выражения могут содержать точки..
						result~=item[15..$];
						break;
					case "int_":
						result~=chunks[2].to!int;
						break;
					case "bool_":
						result~=chunks[2].to!bool;
						break;
					case "null_":
						result~=null;
						break;
					case "float_":
						//наверное с флоатом тоже, что и со строкой, т.к. точки
						result~=item[15..$].to!float;
						break;
					case "array":
						depthA~=item[7..$];
						break;
					case "object":
						depthO~=item[7..$];
						break;
					default:break;
				}
			}
			if(depthA.length>0)result~=deserializeTags(depthA);
			if(depthO.length>0)result~=deserializeTags(depthO);
			return result;
		}else if(tags[0].indexOf("!object.")==0){
			Json result=Json.emptyObject;
			string[][string] depthA;
			string[][string] depthO;
			//тут чуть сложнее, т.к. нужно сладывать массивы и объекты к ключам.
			foreach(string item; tags){
				string[] chunks=item.split(".");
				string key=chunks[1].split("!")[0];
				string valType=chunks[1].split("!")[1];
				switch(valType){
					case "string":
						//в чистом виде сплит не очень, т.к. строковые выражения могут содержать точки..
						result[key]=item[16+key.length..$];
						break;
					case "int_":
						result[key]=chunks[2].to!int;
						break;
					case "bool_":
						result[key]=chunks[2].to!bool;
						break;
					case "null_":
						result[key]=null;
						break;
					case "float_":
						//наверное с флоатом тоже, что и со строкой, т.к. точки
						result[key]=item[16+key.length..$].to!float;
						break;
					case "array":
						depthA[key]~=item[(8+chunks[1].indexOf("!"))..$];
						break;
					case "object":
						depthO[key]~=item[(8+chunks[1].indexOf("!"))..$];
						break;
					default:break;
				}
			}
			if(depthA.length>0){
				foreach(string key,val;depthA)
					result[key]=deserializeTags(val);
			}
			if(depthO.length>0){
				foreach(string key,val;depthO)
					result[key]=deserializeTags(val);
			}
			return result;
		}
	}
	return Json.emptyObject;
}
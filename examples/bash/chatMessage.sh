#!/bin/bash
if [ "$#" -lt 1 ]; then
	wget "http://localhost:4445/push/chat/invoke" --quiet --header="Content-Type: application/json" --post-data='{"tags":"message","data":{"text":"Hello from Linux","from":"bash"}}' -O -
else
	msg='{"tags":"message","data":{"text":"'$@'","from":"bash"}}'
	wget "http://localhost:4445/push/chat/invoke" --quiet --header="Content-Type: application/json" --post-data="$msg" -O -
fi
echo

#!/bin/bash
wget "http://localhost:4445/push/chat/invoke" --quiet --header="Content-Type: application/json" --post-data='{"tags":"message","data":{"text":"Hello from Linux","from":"bash"}}' -O -
echo
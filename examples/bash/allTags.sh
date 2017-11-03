#!/bin/bash
wget "http://localhost:4445/push/chat/invoke" --quiet --header="Content-Type: application/json" --post-data='["console",{"message":{"from":{"id":333},"text":"simple message","private":true,"value":null}}]' -O -
echo
#!/bin/bash
# usage: ./sros.sh file.cfg   |   ./sros.sh "show lag" "show port"
# Sends MD-CLI lines to the BNG over SSH and prints the session output.
host=${SROS_HOST:-172.31.249.10}
if [ -f "$1" ]; then cmds=$(cat "$1"); else cmds=$(printf '%s\n' "$@"); fi
{ echo "environment more false"; printf '%s\n' "$cmds"; echo "logout"; } |
  sshpass -p 'NokiaSros1!' ssh -tt -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR admin@"$host" 2>&1 | tr -d '\r' | sed '1,/environment more false/d'

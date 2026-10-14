#!/bin/bash
# Reachability core -> CPE side of every SAP on lag-14
. "$(dirname "$0")/lab.env"
for ip in $ALL_SAPS; do
  printf '%-14s ' "$ip"
  sudo docker exec $CORE ping -c2 -W1 -q "$ip" | grep -oE '[0-9]+% packet loss'
done

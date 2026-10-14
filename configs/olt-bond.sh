#!/bin/bash
# usage: olt-bond.sh add|del ethN [ethM ...]
op=$1; shift
for i in "$@"; do
  ip link set $i down
  if [ "$op" = add ]; then ip link set $i master bond0; else ip link set $i nomaster; fi
  ethtool -K $i tx off >/dev/null 2>&1
  ip link set $i up
done
grep -E 'Slave Interface|Aggregator ID|MII Status' /proc/net/bonding/bond0

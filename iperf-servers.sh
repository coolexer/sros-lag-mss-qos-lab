#!/bin/bash
# (re)start iperf3 servers on the OLT, one set per SAP address
. "$(dirname "$0")/lab.env"
sudo docker exec $OLT sh -c "
pkill iperf3; sleep 1
for ip in $ALL_SAPS; do
  for p in 5201 5202 5203 5204; do iperf3 -s -D -B \$ip -p \$p; done
done
pgrep iperf3 | wc -l"

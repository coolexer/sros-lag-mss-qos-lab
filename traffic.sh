#!/bin/bash
# usage: traffic.sh <rate-per-stream> <streams> <seconds> ip:port [ip:port ...]
# UDP iperf3 core -> olt; prints received rate per target and per LAG member (olt eth1..eth5 rx).
. "$(dirname "$0")/lab.env"
rate=$1; streams=$2; t=$3; shift 3
rx() { sudo docker exec $OLT cat /sys/class/net/$1/statistics/rx_bytes; }

bash "$(dirname "$0")/iperf-servers.sh" >/dev/null
sleep 1

declare -A b0 d
for i in 1 2 3 4 5; do b0[$i]=$(rx eth$i); done

for tgt in "$@"; do
  ip=${tgt%:*}; port=${tgt#*:}
  sudo docker exec $CORE iperf3 -c "$ip" -p "$port" -u -b "$rate" -P "$streams" -t "$t" -l 1200 -f k \
    > /tmp/iperf-$ip-$port.txt 2>&1 &
  sleep 0.5
done
wait

echo "== received per target (offered: $streams x $rate) =="
for tgt in "$@"; do
  ip=${tgt%:*}; port=${tgt#*:}
  line=$(grep receiver /tmp/iperf-$ip-$port.txt | tail -1)
  if [ -z "$line" ]; then
    printf '%-20s FAILED: %s\n' "$tgt" "$(tail -1 /tmp/iperf-$ip-$port.txt)"
  else
    printf '%-20s %-18s loss %s\n' "$tgt" "$(echo "$line" | grep -oE '[0-9.]+ Kbits/sec' | head -1)" \
      "$(echo "$line" | grep -oE '\([0-9.e+-]+%\)')"
  fi
done

echo "== per LAG member (olt rx) =="
tot=0
for i in 1 2 3 4 5; do d[$i]=$(( $(rx eth$i) - b0[$i] )); tot=$(( tot + d[$i] )); done
for i in 1 2 3 4 5; do
  [ "${d[$i]}" -lt 20000 ] && continue
  printf 'eth%s  %8d kbit/s  %5.1f%%\n' $i $(( d[$i] * 8 / t / 1000 )) $(echo "${d[$i]} * 100 / $tot" | bc -l)
done
printf 'total %7d kbit/s\n' $(( tot * 8 / t / 1000 ))

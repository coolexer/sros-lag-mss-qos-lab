#!/bin/bash
# OLT emulator: LACP bond towards lag-14 + QinQ subinterfaces = CPE side of each SAP.
# Members eth3..eth5 stay outside the bond until a scenario adds them (see olt-bond.sh).

for i in 1 2 3 4 5; do
  until ip link show eth$i >/dev/null 2>&1; do sleep 1; done
done

ip link add bond0 type bond mode 802.3ad miimon 100 lacp_rate fast xmit_hash_policy layer3+4
for i in eth1 eth2; do
  ip link set $i down
  ip link set $i master bond0
done
ip link set bond0 up
ip link add link bond0 name s100 type vlan id 100
ip link set s100 up

# inner-vlan olt-ip/len bng-gw table
add_sap() {
  ip link add link s100 name v$1 type vlan id $1
  ip link set v$1 up
  ip addr add $2 dev v$1
  ip rule add from ${2%/*} table $4
  ip route add 192.168.0.0/16 via $3 dev v$1 table $4
}
add_sap 17 10.10.17.2/30 10.10.17.1 17
add_sap 18 10.10.18.2/30 10.10.18.1 18
add_sap 15 10.10.15.2/30 10.10.15.1 15
add_sap 11 10.10.11.2/30 10.10.11.1 11
add_sap 13 10.10.13.2/30 10.10.13.1 13
add_sap 16 10.10.16.2/30 10.10.16.1 16

# lag-14:200.*, single outer tag
ip link add link bond0 name v200 type vlan id 200
ip link set v200 up
ip addr add 10.10.200.1/24 dev v200
ip rule add from 10.10.200.1 table 200
ip route add 192.168.0.0/16 via 10.10.200.254 dev v200 table 200

# veth checksum offload leaves partial checksums that the simulator forwards unchanged
for i in $(ls /sys/class/net); do ethtool -K $i tx off >/dev/null 2>&1; done

# bind to the SAP address so UDP replies hit the per-SAP policy route (not eth0)
for ip in 10.10.17.2 10.10.18.2 10.10.15.2 10.10.11.2 10.10.13.2 10.10.16.2 10.10.200.1; do
  for p in 5201 5202 5203 5204; do iperf3 -s -D -B $ip -p $p; done
done

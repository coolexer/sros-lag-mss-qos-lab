#!/bin/bash
# Upstream host: one dot1q VLAN per VPRN on BNG 1/1/c1/1, iperf3 clients run from here.

until ip link show eth1 >/dev/null 2>&1; do sleep 1; done
ip link set eth1 up

add_vlan() {
  ip link add link eth1 name v$1 type vlan id $1
  ip link set v$1 up
  ip addr add 192.168.$1.1/24 dev v$1
}
add_vlan 17    # VPRN 1001 -> SAP 100.17 (MSS)
add_vlan 18    # VPRN 1002 -> SAP 100.18 (MSS)
add_vlan 15    # VPRN 1003 -> SAP 100.15 (MSS)
add_vlan 22    # VPRN 1004 -> SAP 100.11/.13/.16 (SAP scheduler)
add_vlan 200   # VPRN 1005 -> SAP 200.*

ip route add 10.10.17.0/30  via 192.168.17.254
ip route add 10.10.18.0/30  via 192.168.18.254
ip route add 10.10.15.0/30  via 192.168.15.254
ip route add 10.10.11.0/30  via 192.168.22.254
ip route add 10.10.13.0/30  via 192.168.22.254
ip route add 10.10.16.0/30  via 192.168.22.254
ip route add 10.10.200.0/24 via 192.168.200.254

# veth checksum offload leaves partial checksums that the simulator forwards unchanged
for i in $(ls /sys/class/net); do ethtool -K $i tx off >/dev/null 2>&1; done

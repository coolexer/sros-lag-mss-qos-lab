#!/bin/bash
# Runs every scenario in order; raw output of each one goes to results/<scenario>.txt
cd "$(dirname "$0")"; . ./lab.env
mkdir -p results

bond()     { sudo docker exec $OLT bash /opt/lab/olt-bond.sh "$@" >/dev/null; }
cfg()      { ./sros.sh "configs/$1" | grep -E -A3 'MINOR|MAJOR|CRITICAL'; }
lagports() { ./sros.sh 'show lag 14 port' | grep -E '/1/c'; }
assoc()    { ./sros.sh 'show lag 14 associations per-link-hash sap' | grep -E 'lag-14:|SvcId'; }
wait_lag() { # $1 = number of members expected up/active
  for _ in $(seq 1 30); do [ "$(lagports | grep -cE 'up +active +up')" -ge "$1" ] && break; sleep 5; done
  sleep 10; lagports
}
targets()  { for ip in "$@"; do printf '%s:5201 ' "$ip"; done; }
step()     { echo; echo "######## $*"; }
scenario() { local f=$1; shift; echo ">>> results/$f.txt"; "$@" 2>&1 | tee "results/$f.txt"; }

s00_setup() {
  step "apply base config (lag-14 = 3/1/c1/1 + 3/1/c2/1, adapt-qos distribute)"
  cfg bng-base.cfg
  for _ in $(seq 1 60); do
    [ "$(./sros.sh 'show card' | grep -cE '^[13] .* up +up')" -eq 2 ] && break; sleep 5
  done
  ./sros.sh 'show card' 'show mda' | grep -E '^[0-9AB] |^[13] +1 '
  wait_lag 2
  step "reachability core -> every SAP"; ./ping-all.sh
}

s01_sim() {
  step "SAP 100.11 egress scheduler 5000 kbps"
  ./sros.sh 'show qos scheduler-hierarchy sap lag-14:100.11 egress' | grep -E 'Policy|\((S|Q)\)|slot'
  step "offer 8 Mbps (4 x 2M) into the 5 Mbps SAP scheduler"
  ./traffic.sh 2M 4 15 $(targets $SAP_100_11)
  ./sros.sh 'show service id 1004 sap lag-14:100.11 stats' | grep -A4 'Egress Queue 1'
  step "offer 30 Mbps (6 x 5M) into SAP 200.* (queue 8000 kbps): datapath ceiling 1000 pps/port"
  ./traffic.sh 5M 6 15 $(targets $SAP_200)
}

s02_a() {
  step "MSS tree: one slot, ROOT and every queue instance"; ./mss-snap.sh
  step "3 MSS SAPs x 2 flows x 1.4M: per-flow spray over both members"
  ./traffic.sh 1.4M 2 15 $(targets $MSS_SAPS)
  step "single 8 Mbps flow into SAP 100.17: one member only"
  ./traffic.sh 8M 1 15 $(targets $SAP_100_17)
}

s03_c() {
  step "try per-fp-egr-queuing on the distribute LAG with VPRN SAPs"
  ./sros.sh configs/c-per-fp.cfg | grep -E 'commit|MINOR'
}

s04_b() {
  step "B1: + 1/1/c2/1 (2 members on card 3, 1 on card 1)"
  cfg b1-add-card1.cfg; bond add eth3; wait_lag 3
  ./mss-snap.sh | grep -vE 'MBS'
  ./traffic.sh 350K 8 15 $(targets $MSS_SAPS)
  step "B2: - 3/1/c2/1 (1 member on card 3, 1 on card 1)"
  cfg b2-split.cfg; bond del eth2; wait_lag 2
  ./mss-snap.sh | grep -vE 'MBS'
  ./traffic.sh 350K 8 15 $(targets $MSS_SAPS)
  bond add eth2; bond del eth3
}

s05_d() {
  step "rebuild lag-14: distribute include-egr-hash-cfg + per-link-hash + per-fp-egr-queuing"
  cfg reset.cfg; cfg d-lag.cfg; cfg bng-base.cfg; wait_lag 2
  ./sros.sh 'edit-config read-only' 'info /configure lag "lag-14"' 'quit-config' | sed -n '/^    /p'
  step "SAP -> link (plain per-link-hash)"; assoc
  step "SAP 100.11 scheduler: one queue instance"
  ./sros.sh 'show qos scheduler-hierarchy sap lag-14:100.11 egress detail' | grep -E '\((S|Q)\)|slot|OperPIR:[0-9]+ kbps *$'
  step "MSS tree"; ./mss-snap.sh
  step "traffic: all 7 SAPs x 4 flows"
  ./traffic.sh 300K 4 12 $(targets $ALL_SAPS)
}

s06_d2() {
  step "per-link-hash weighted auto-rebalance true"
  cfg d-weighted.cfg; sleep 15; assoc
  ./traffic.sh 300K 4 12 $(targets $ALL_SAPS)
}

s07_e() {
  step "E1: 3/1/c1/1 admin down"
  cfg port-c1-down.cfg; sleep 15; lagports; assoc; ./mss-snap.sh | grep -vE 'MBS'
  ./traffic.sh 300K 4 12 $(targets $ALL_SAPS)
  step "E2: 3/1/c1/1 admin up (auto-rebalance timer 5 s)"
  cfg port-c1-up.cfg; wait_lag 2; sleep 15; assoc; ./mss-snap.sh | grep -vE 'MBS'
  ./traffic.sh 300K 4 12 $(targets $ALL_SAPS)
}

s08_f() {
  step "F: + 3/1/c3/1 + 3/1/c4/1 (4 members on card 3)"
  bond add eth4 eth5; cfg f-4links.cfg; wait_lag 4; sleep 15
  assoc; ./mss-snap.sh | grep -vE 'MBS'
  ./traffic.sh 300K 4 12 $(targets $ALL_SAPS)
}

scenario 00-setup                     s00_setup
scenario 01-simulator-datapath        s01_sim
scenario 02-A-distribute-same-card    s02_a
scenario 03-C-per-fp-egr-queuing      s03_c
scenario 04-B-two-cards               s04_b
scenario 05-D-per-link-hash-per-fp    s05_d
scenario 06-D2-weighted-auto-rebalance s06_d2
scenario 07-E-link-failure            s07_e
scenario 08-F-four-members            s08_f

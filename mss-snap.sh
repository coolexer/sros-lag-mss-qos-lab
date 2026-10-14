#!/bin/bash
# MSS scheduler tree, condensed: object, slot, oper PIR, MBS
cd "$(dirname "$0")"
./sros.sh 'show qos scheduler-hierarchy customer 2 site "MSS_93M_SITE-A" egress detail' |
  grep -E '\((S|Q)\) :|slot\(|OperPIR:[0-9]+ kbps *$|MBS:' | sed -E 's/^[| ]+//'

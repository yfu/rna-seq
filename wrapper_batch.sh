#!/usr/bin/env bash

# Generate a bsub to run run.sh

for i in HEIL JMAC KNBD OQSU PRTV
do
    for j in id1 id2 id3 id4 id5 id6
    do
	left=$i.r1_$j.fq
	right=$i.r2_$j.fq
	echo "Running: ./run.sh -l $left -r $right -c 20"
cat << EOF | bsub
#!/bin/bash

#BSUB -n 20
#BSUB -R rusage[mem=20480] # ask for memory
#BSUB -W 10:00
#BSUB -q short # which queue we want to run in
##BSUB -R "select[chassisno>0] same[chassisno]" # All hosts on the same chassis
#BSUB -o /home/yf60w/logs/%J.%I.out
#BSUB -e /home/yf60w/logs/%J.%I.err
./run.sh -l $left -r $right -c 20

EOF
    done
done



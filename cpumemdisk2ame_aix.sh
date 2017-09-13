#!/bin/ksh

# new script to collect basic monitoring and send it of to ame for aix clients.
# created by Erik Schaberg
# version 0.8



CONFIGURLPATH="/home/samescripts/"
DPCLASSGRP="OS"
DPCLASS_CPU="CPU"
DPCLASS_MEM="MEM"
DPCLASS_DISK="DISK"
DPNAME_CPU="CPU_usage"
DPNAME_MEM="Memory_usage"
SERVER_NAME=`uname -a|awk '{print $2}'|tr a-z A-Z`
POSTCOMMONCPU="hostname=$SERVER_NAME&dpclassgrp=$DPCLASSGRP&dpclass=$DPCLASS_CPU"
POSTCOMMONMEM="hostname=$SERVER_NAME&dpclassgrp=$DPCLASSGRP&dpclass=$DPCLASS_MEM"
POSTCOMMONDISK="hostname=$SERVER_NAME&dpclassgrp=$DPCLASSGRP&dpclass=$DPCLASS_DISK"
SAMPLE_TIME=10
TIMEOUT=5
TRIES=2

# first a random wait to make sure not all servers hit the ame web server at the same time.
RAN=$RANDOM
SL=$(( RAN %= 60 )) 
sleep $SL

# Doe 2 samples met een tussenpauze van $SAMPLE_TIME
echo "Hold on... sampling for $SAMPLE_TIME seconds."
vmstat ${SAMPLE_TIME} 2 > /tmp/msg$$

# Haal huidig CPU gebruik op en verstuur naar AME
DPVALUE=$(cat /tmp/msg$$| tail -n -1 | awk '{ print 100-$16 }')
rm /tmp/msg$$
POSTDATA="$POSTCOMMONCPU&dpname=$DPNAME_CPU&dpvalue=$DPVALUE&dpdescription=cpu_usage_high"
wget --timeout=$TIMEOUT --tries=$TRIES -i ${CONFIGURLPATH}dropsi.url -O - --post-data=$POSTDATA

# Haal huidge MEM gebruik op en verstuur naar AME
USED=`svmon -G | head -2 | tail -1 | awk '{ print $3 }'`
USED=`expr $USED / 256`
TOTAL=`lsattr -El sys0 -a realmem | awk '{ print $2 }'`
TOTAL=`expr $TOTAL / 1000`
DPVALUE=`echo "scale=2; $USED / $TOTAL * 100" | bc | cut -d'.' -f 1`

POSTDATA="$POSTCOMMONMEM&dpname=$DPNAME_MEM&dpvalue=$DPVALUE&dpdescription=mem_usage_high"
wget --timeout=$TIMEOUT --tries=$TRIES -i ${CONFIGURLPATH}dropsi.url -O - --post-data=$POSTDATA

# retrieve filesystem usage info for key filesystems
for i in `df -P | egrep -v "Tivoli|Mounted|mksysbfs|DoOnceAIX|proc|SCM|ITM|livedum|livedumpp|aha|aixinstall|install|mnt|tsmupdate" | grep "%"| awk '{ sub(/%/,""); print $5 ","$6 }'`
do
   IFS=, 
   set $i
   usage=$1
   fs=$2
   POSTDATA="$POSTCOMMONDISK&dpname=$fs&dpvalue=$usage&dpdescription=$fs"
   wget --timeout=$TIMEOUT --tries=$TRIES -i ${CONFIGURLPATH}dropsi.url -O - --post-data=$POSTDATA
done 

#!/bin/bash

#start monitoring adb device for reboots with a test run description

set -e
#set -x

if [ $# -lt 1 ]; then
    echo "Usage: monitor.sh \"Run Description\""
    exit 1
fi

run=$(date +"%Y-%m-%d_%T")
restarts=0

mkdir -p ./logs
logfile="./logs/${run}.log"

log () {
  now=$(date +"%Y-%m-%d %T")
  echo "$now: $1"
  echo "$now: $1" >> "$logfile"
}

startFilter() {
    target=$(basename $1)
    if [ -f "${target}_triggers.txt" ]; then
        tail -f "./logs/${run}_${restarts}_${target}" | grep --line-buffered -F -f "${target}_triggers.txt" | (
        while read -r line; do
            log "trigger found in ${target}: ${line}";
        done;
        )
    fi
}

startTail() {
    target=$(basename $1)
    adb shell "busybox tail -f $1" >> "./logs/${run}_${restarts}_${target}" &
    startFilter "$1" &
}

startTails() {
    startTail "/blackbox/system/kmsg.log"
    startTail "/blackbox/system/fatal.log"
}
sdCleanup() {
    #echo "running sd card cleaup"
    adb shell "rm -f \$(busybox ls -1td /storage/sdcard0/DCIM/100MEDIA/* | tail -n "+5")" || true
}
startSlowSDAvoid() {
    #wait a little for it to be mounted
    sleep 10
    while :
    do
        sdCleanup
        sleep 60
    done
}
logDeviceState() {
    logState "dinit" "dinitctl list"
    logState "opkg" "opkg list-installed"
    #log "dinit state:\n$(adbShell 'dinitctl list')"
    #log "opkg state:\n$(adbShell 'opkg list-installed')"
}
logState() {
    log "dumping $1 state:"
    adbShell "$2" | (
        while read -r line; do
            log "${line}";
        done;
        )
}
adbShell() {
    adb shell ". /etc/mkshrc; $1" | grep -v "secure debug value 0x1"
}

echo "$(date +"%Y-%m-%d %T"): Looking for adb device"
adb wait-for-device
#avoid raceconds during boot
sleep 15
log "Device found, starting monitoring run"
log "Run description is: $1"

logDeviceState

startTails
startSlowSDAvoid &

while :
do
	if ! adb devices | grep -q "987654321ABCDEF"; then
        restarts=$((restarts+1))
        log "Restart #${restarts} detected"
        adb wait-for-device
        log "Device came back, resuming monitoring"
        #racecond, have to wait for dji_blackbox to complete rotating logs
        sleep 15
        startTails
    else
	    sleep 1
    fi
done
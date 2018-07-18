#!/bin/bash

# Jon pulled this Bash script for an iBeacon Scanner.  We reconfigured it for Fujitsu beacons
# from Radius Networks referenced in this StackOverflow answer:
# http://stackoverflow.com/questions/21733228/can-raspberrypi-with-ble-dongle-detect-ibeacons?lq=1

# Radius's original Process:
# 1. start hcitool lescan
# 2. begin reading from hcidump
# 3. packets span multiple lines from dump, so assemble packets from multiline stdin
# 4. for each packet, process into uuid, major, minor, power, and RSSI
# Note that iBeacons come in this format, but Fujitsu's beacons do not. Therefore, we need to customize how we read the packets.
# 5. when finished (SIGINT): make sure to close out hcitool

# The hcitool will run indfinitely, so we need to kill the process specifically 
halt_hcitool_lescan() {
  sudo pkill --signal SIGINT hcitool
}

# ?? What does this do? 
trap halt_hcitool_lescan INT

# This function(?) processes the incoming data packet  
process_complete_packet() {
  # an example iBeacon packet:
  # >04 3E 2A 02 01 03 00 CA 66 69 70 F3 5C 1E 02 01 1A 1A FF 4C 00 02 15 2F 23 44 54 CF 6D 4A 0F AD F2 F4 91 1B A9 FF A6 00 01 00 01 C5 B2
  # This Bash script was originally setup to output: 
  # => 2F234454-CF6D-4A0F-ADF2-F4911BA9FFA6    1       73       -59     -78
  # where UUID: 2F234454-CF6D-4A0F-ADF2-F4911BA9FFA6 MAJOR: 1 MINOR: 73 POWER: -59 RSSI: -78

  # ?? What does this do? 
  local packet=${1//[\ |>]/}

  # We're looking for Fujitsu packets which we know have payloads containing 010003000300
  # If the BLE packet doesn't containt 010003000300 then exit the Bash script 
  if [[ ! $packet =~ 010003000300 ]]; then
    return
  fi
  # If we reached this spot in the script, then we're dealing with a Fujitsu packet 
  # output [epoch time] when the data arrived and the payload 
  echo "[`date +"%s"`] $packet"

 # This section originally existed to parse the iBeacon payload, but doesn't apply for Fujitsu. 
 # uuid="${packet:46:8}-${packet:54:4}-${packet:58:4}-${packet:62:4}-${packet:66:12}"
 # major=$((0x${packet:78:4}))
 # minor=$((0x${packet:82:4}))
 # power=$[$((0x${packet:86:2})) - 256]
 # rssi=$[$((0x${packet:88:2})) - 256]
 #
 # echo -e "$uuid\t$major\t$minor\t$power\t$rssi"
}

#This function reads and assembles the packet: 
read_blescan_packet_dump() {
  # packets span multiple lines and need to be built up
  packet=""
  while read line; do
    # packets start with ">"
    if [[ $line =~ ^\> ]]; then
      # process the completed packet (unless this is the first time through)
      if [ "$packet" ]; then
        process_complete_packet "$packet"
      fi
      # start the new packet
      packet=$line
    else
      # continue building the packet
      packet="$packet $line"
    fi
  done
}

# begin BLE scanning
sudo hcitool lescan --duplicates > /dev/null &
sleep 1
# make sure the scan started
if [ "$(pidof hcitool)" ]; then
  # start the scan packet dump and process the stream
  sudo hcidump --raw | read_blescan_packet_dump
else
  echo "ERROR: it looks like hcitool lescan isn't starting up correctly" >&2
  exit 1
fi

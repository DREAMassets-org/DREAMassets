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

# This command means that the script stops when we hit Ctrl-c
trap halt_hcitool_lescan INT

# This function(?) processes the incoming data packet
process_complete_packet() {
  # an example iBeacon packet:
  # >04 3E 2A 02 01 03 00 CA 66 69 70 F3 5C 1E 02 01 1A 1A FF 4C 00 02 15 2F 23 44 54 CF 6D 4A 0F AD F2 F4 91 1B A9 FF A6 00 01 00 01 C5 B2
  # This Bash script was originally setup to output:
  # => 2F234454-CF6D-4A0F-ADF2-F4911BA9FFA6    1       73       -59     -78
  # where UUID: 2F234454-CF6D-4A0F-ADF2-F4911BA9FFA6 MAJOR: 1 MINOR: 73 POWER: -59 RSSI: -78

  # at this point $1 is the argument passed into this function
  # This strips the > and whitespace from the packet data
  # and assigns it to $packet

  local packet=${1//[\ |>]/}
  local timestamp=${2}

  # If we reached this spot in the script, then we're dealing with a Fujitsu packet
  # output as JSON for easy consumption
  echo "{ \"timestamp\": \"$timestamp\", \"packet_data\": \"$packet\" }"

  # This section originally existed to parse the iBeacon payload, but doesn't apply for Fujitsu.
  # uuid="${packet:46:8}-${packet:54:4}-${packet:58:4}-${packet:62:4}-${packet:66:12}"
  # major=$((0x${packet:78:4}))
  # minor=$((0x${packet:82:4}))
  # power=$[$((0x${packet:86:2})) - 256]
  # rssi=$[$((0x${packet:88:2})) - 256]
  #
  # echo -e "$uuid\t$major\t$minor\t$power\t$rssi"
}

# This function reads and assembles the packet because packets span multiple lines and need to be built up
# This function is unclear -- Mike and Jon to discuss

WITH_TIMESTAMP_REGEX="^([0-9]{4}-[0-9]{2}-[0-9]{2}.*)\s+>(.*)$"
WITHOUT_TIMESTAMP_REGEX="^()>(.*)$"

read_blescan_packet_dump() {

  # start with an empty string(?)
  packet=""
  # read a line and look for the starting character ">" or with timestamp like "2018-07-18 10:56:08.151507 >"
  while read line; do
    # packets start with ">" ### Mike got lost here. Are we actually looking for the beginning of the *next* packet??
    if [[ $line =~ $WITHOUT_TIMESTAMP_REGEX ]] || [[ $line =~ $WITH_TIMESTAMP_REGEX  ]]; then
      # process the completed packet (unless this is the first time through)  ### Is this unique to the first run or any new packet?
      if [ "$packet" ]; then
        process_complete_packet "$packet" "$timestamp"
      fi
      # start the new packet
      timestamp=${BASH_REMATCH[1]}
      packet=${BASH_REMATCH[2]}
    else
      # continue building the packet
      packet="$packet $line"
    fi
  done
}

# Here's where the functions stop and the actual scanning begins (?)
# begin BLE scanning and remove duplicate data packets -- they're not useful for our purposes.
# What does the second part of the command do? > /dev/null & ???
sudo hcitool lescan --duplicates > /dev/null &
# sleep to pause for 1 second so that hcitool can launch
sleep 1
# make sure the scan started by finding the process ID of a running program using pidof. If there's no ID, the program hasn't started yet.
# pidof is defined here: https://linux.die.net/man/8/pidof
# It looks like "$()" creates an array, so the if statement is checking whether the array is null (???)
# $() is defined here https://stackoverflow.com/questions/5163144/what-are-the-special-dollar-sign-shell-variables
if [ "$(pidof hcitool)" ]; then
  # start the scan packet dump (with timestamps -t) and process the stream of payloads to be formatted for easier processing.
  sudo hcidump -t --raw | read_blescan_packet_dump
else
  echo "ERROR: it looks like hcitool lescan isn't starting up correctly" >&2
  exit 1
fi

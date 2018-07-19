#!/bin/bash
# Declare that this is a Bash script
# https://stackoverflow.com/questions/8967902/why-do-you-need-to-put-bin-bash-at-the-beginning-of-a-script-file 

# Jon pulled this Bash script for an iBeacon Scanner.  We reconfigured it for the DREAM project with Fujitsu beacons
# The script was originally developed by Radius Networks for iBeacons. Here's the source:
# http://stackoverflow.com/questions/21733228/can-raspberrypi-with-ble-dongle-detect-ibeacons?lq=1

# Here's how our modified DREAM script works
# 0. Separate from this script, there are nearby beacons using Bluetooth Low Energy (BLE) to send out data packets in advertising/broadcast mode.
#    This Bash script sits on a Raspbeery Pi and enables the RPi to capture those data packets for later processing. 
#
# 1. Start the BLE scanner using the command: `sudo hcitool lescan --duplicates > /dev/null &` 
#    sudo = use the privelges of a superuser https://en.wikipedia.org/wiki/Sudo
#    hcitool lescan = start the BLE scanner https://www.systutorials.com/docs/linux/man/1-hcitool/
#    --duplicates = remove duplicate packets since the redundancy isn't helpful
#    > /dull/null = redirect the output to a null file; we're throwing away the output. ">" is for files. 
#    & = run this command in the background since we need to run hcitool and hcidump simultaneously 
#    
# 2. Verify that the scanner started using the command: `if [ "$(pidof hcitool)" ]; then`
#    pidof = finds the process ID of a running program.  https://linux.die.net/man/8/pidof
#    if ["... = Evaluate whether there's a process ID. If there's no ID, the program hasn't started, therefore error. 
#
# 3. Output the data from the BLE scanner using the command: `sudo hcidump -t --raw | read_blescan_packet_dump`
#    sudo = superuser
#    hcidump = get the output from the BLE scanner 
#    -t = include the timestamp when the data arrived 
#    --raw = provide the raw hexadecimal data. By default, hcidump formats and presents the data with labels. `--raw` outputs data without labels, but still needs some cleaning
#    | read_blescan_packet_dump = pump the data into a function called read_blescan_packet_dump. "|" is for functions; if we used ">" instead, the data would go into a file with the name read_blescan_packet_dump
#    
#    `hcidump --raw` has two data-cleanliness problems that this Bash script solves: 
#    (1) `hcidump` returns only 40 bytes per line. If a BLE advertising packet makes the data more than 40 bytes, then hcidump line wraps.
#    `read_blescan_packet_dump` is our function that removes the carriage returns and gathers all the data from a packet 
#    (2) `hcidump --raw` outputs characters that aren't bytes: ">" and " " (carrots and whitespace)
#    `process_complete_packet` is our function that removes those characters and simplifies the data packet to just bytes. 
# 
# 4. Close with ctrl-c. We're running hcitool in the background (the `&` did this), so we need to to specify to close hcitool. 
#    Since hcidump is in the foreground, ctrl-c will just kill it.
#    

# The hcitool will run indfinitely, so this function specifies that we kill it
# https://www.quora.com/What-is-the-difference-between-the-SIGINT-and-SIGTERM-signals-in-Linux
# https://www.computerhope.com/unix/utrap.htm
halt_hcitool_lescan() {
  sudo pkill --signal SIGINT hcitool
}
trap halt_hcitool_lescan INT

# process_complete_packet is our function that removes carrots and whitespace from a data packet 
process_complete_packet() {
  # take the first argument, $1, and set it to be the packet variable 
  # also, in the packet: find any character that is "\ " (escape-character white space) or ">" (a greater than character). 
  # Replace those characters with nothing -- because there's nothing in the first two slashes "//" 
  local packet=${1//[\ |>]/}
  # take the second argument, $2, and  set it to be the timestamp variable 
  local timestamp=${2}

  # We're looking for Fujitsu packets which we know have payloads containing 010003000300
  # If the BLE packet doesn't containt 010003000300 then skip the output of this packet
  if [[ ! $packet =~ 010003000300 ]]; then
    return
  fi

  # If we reached this spot in the script, then we're dealing with a Fujitsu packet
  # output as JSON for easy consumption
  echo "{ \"timestamp\": \"$timestamp\", \"packet_data\": \"$packet\" }"
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
    if [[ $line =~ $WITH_TIMESTAMP_REGEX ]] || [[ $line =~ $WITHOUT_TIMESTAMP_REGEX  ]]; then
      # extract the regex matches immediately
      tmp_timestamp=${BASH_REMATCH[1]}
      tmp_packet=${BASH_REMATCH[2]}

      # process the completed packet (unless this is the first time through)  ### Is this unique to the first run or any new packet?
      if [ "$packet" ]; then
        process_complete_packet "$packet" "$timestamp"
      fi

      # start the new packet
      timestamp=$tmp_timestamp
      packet=$tmp_packet
    else
      # continue building the packet
      packet="$packet $line"
    fi
  done
}

# Here's where the functions stop and the actual scanning begins (?)
# begin BLE scanning and remove duplicate data packets -- they're not useful for our purposes.
# What does the second part of the command do? > /dev/null & ???
# /dev/null -- throw away the data stream
# & run this in the background 
sudo hcitool lescan --duplicates > /dev/null &
# sleep to pause for 2 seconds so that hcitool can launch
sleep 2
# make sure the scan started by finding the process ID of a running program using pidof. If there's no ID, the program hasn't started yet.
# pidof is defined here: https://linux.die.net/man/8/pidof
# It looks like "$()" creates an array, so the if statement is checking whether the array is null (???)
# $() is defined here https://stackoverflow.com/questions/5163144/what-are-the-special-dollar-sign-shell-variables
if [ "$(pidof hcitool)" ]; then
  # start the scan packet dump (with timestamps -t) and process the stream of payloads to be formatted for easier processing.
  sudo hcidump -t --raw | read_blescan_packet_dump
else
  # echo standard out and standard error. >&2 redirect to output on error. 
  # if we said each "blah blah" >&1 it'd be redundant 
  echo "ERROR: it looks like hcitool lescan isn't starting up correctly" >&2
  exit 1
fi

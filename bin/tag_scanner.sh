#!/bin/bash
# Declare that this is a Bash script
# https://stackoverflow.com/questions/8967902/why-do-you-need-to-put-bin-bash-at-the-beginning-of-a-script-file
#
# 
# PROBLEM: 
# We need to read, aggregate, filter, and JSON-ify the Bluethooth data to make it useful
# RasPi gathers BLE data by running two commands simultaneously: `hcitool` and `hcidump`. 
# The output from hcitool is a list of BLE tag IDs and labels, but no data.
# The output from hcidump is a timestamp followed by raw BLE data packets. 
#
# Here's sample output of BLE device IDs and labels from `hcitool`: 
# 1E:91:E8:B0:AF:DA (unknown)
# 88:C6:26:CA:42:47
# 7C:64:56:36:1F:D9 (unknown)
# 2C:41:A1:03:20:5D LE-QC 35 V2
# B0:34:95:38:82:5D (unknown)
# 88:C6:26:CA:42:47 (unknown)
# D4:A1:BD:1F:46:F2 (unknown)
# 21:D6:07:DF:B1:04 (unknown)
# 
# We don't care about most of the BLE devices in this output -- which is why we need to filter data.
# The BLE device ID `D4:A1:BD:1F:46:F2` is a Fujitsu beacon -- we're calling these "tags" and we need their data. 
# We only use hcitool because hcidump won't work without it.  This bash script just discards the output from hcitool  
# 
# Here's sample output of timestamps and raw BLE data packets from hcidump:
# 2018-07-26 21:15:45.220743 > 04 3E 0C 02 01 04 00 1E 4F A2 89 5C F4 00 A9
# 2018-07-26 21:15:45.249505 > 04 3E 17 02 01 00 00 F5 73 9A 08 40 6C 0B 02 01 06 07 FF 4C
#   00 10 02 0B 00 A0
# 2018-07-26 21:15:45.272482 > 04 3E 21 02 01 03 01 F2 46 1F BD A1 D4 15 02 01 04 11 FF 59
#   00 01 00 03 00 03 00 FC 01 77 00 45 00 0A 08 BC
# 2018-07-26 21:15:45.332024 > 04 3E 2B 02 01 03 01 39 43 86 CC 64 0F 1F 1E FF 06 00 01 09
#   20 02 58 0C 2B A8 AB D3 6C 9A 4D 5F 39 99 0C 77 56 C1 3E 9D
#   84 E9 C1 E4 29 A2
# 2018-07-26 21:15:45.348606 > 04 3E 17 02 01 00 01 34 4E 89 F2 B8 74 0B 02 01 06 07 FF 4C
#   00 10 02 0B 00 A5
# 2018-07-26 21:15:45.349272 > 04 3E 0C 02 01 04 01 34 4E 89 F2 B8 74 00 A7
# 2018-07-26 21:15:45.382297 > 04 3E 17 02 01 00 00 48 E6 C9 32 BC AC 0B 02 01 06 07 FF 4C
#   00 10 02 0B 00 A7
# 
# Again, our BLE scanner picks up tons of devices. We need to filter down this output to the Fujitsu tags we care about. 
# In raw format, the Fujitsu tag ID D4:A1:BD:1F:46:F2 becomes inverted to `F2 46 1F BD A1 D4` (shown above)
# The bytes `00 01 00 03 00 03 00` are an identifier (010003000300) that this is a Fujitsu beacon
# The bytes `FC 01 77 00 45 00 0A 08 BC` are useful information: temp, x-axis acceleration, y acceleration, z acceleration and RSSI.
# Fujitsu's documentation explains how to convert the bytes to meaningful decimal values. 
# 
# Another problem is that the output from hcidump breaks across lines
# 
# SOLUTION
# This bash script takes the output from hcidump and then 
# (1) Aggregates data for each BLE device across line breaks. 
# (2) Filters the output to be only data from Fujitsu beacons (i.e., containing the identifier 010003000300)
# (3) Outputs a JSON with the timestamp and data packet: Fujitsu beacon tag ID, measurement data, and other junk data. 
#
# The function `aggregate_data_packet` does step (1)
# The function `filter_and_JSONify_fujitsu_packets` does steps (2) and (3)
# There's a separate Ruby script that uses those JSONs as input, processes the measurement data from bytes to meaningful decimal values, and sends the values to Google Cloud 
# 
# 
# Here's how our modified DREAM script works
# 0. Separate from this script, there are nearby beacons using Bluetooth Low Energy (BLE) to send out data packets in advertising/broadcast mode.
#    This Bash script sits on a Raspbeery Pi and enables the RPi to capture those data packets for later processing.
#
# 1. Start the BLE scanner using the command: `sudo hcitool lescan > /dev/null &`
#    sudo = use the privelges of a superuser https://en.wikipedia.org/wiki/Sudo
#    hcitool lescan = start the BLE scanner https://www.systutorials.com/docs/linux/man/1-hcitool/
#    > /dev/null = redirect the output to a null file; we're throwing away the output. ">" is for files.
#    & = run this command in the background since we need to run hcitool and hcidump simultaneously
#
# 2. Verify that the scanner started using the command: `if [ "$(pidof hcitool)" ]; then`
#    pidof = finds the process ID of a running program.  https://linux.die1.net/man/8/pidof
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

# include our bash hci helper functions
script_root_dir="$(dirname "$0")"
lib_dir="${script_root_dir}/../lib/bash/hci_functions.bash"
source $lib_dir

trap halt_hcitool_lescan INT


# Here's where the functions stop and the actual scanning begins (?)
# begin BLE scanning
start_hcitool_lescan

# make sure the scan started by finding the process ID of a running program using pidof. If there's no ID, the program hasn't started yet.
# pidof is defined here: https://linux.die.net/man/8/pidof
# It looks like "$()" creates an array, so the if statement is checking whether the array is null (???)
# $() is defined here https://stackoverflow.com/questions/5163144/what-are-the-special-dollar-sign-shell-variables
if [ "$(pidof hcitool)" ]; then
  # start the scan packet dump (with timestamps -t) and process the stream of payloads to be formatted for easier processing.
  start_hcidump_stream | read_blescan_packet_dump | process_and_filter_fujitsu_packets
else
  # echo standard out and standard error. >&2 redirect to output on error.
  # if we said each "blah blah" >&1 it'd be redundant
  echo "ERROR: it looks like hcitool lescan isn't starting up correctly" >&2
  exit 1
fi

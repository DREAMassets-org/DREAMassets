######
# This bash script includes several functions that help with scanning the BLE packets floating around in the ether.
#
# To use the bash script, you must have the `bluez` and `bluez-hcidump` packages installed on the RasPi 

# ??? DEFINE WHAT A "PACKET IS"
# SHOULD WE DIFFERENTIATE PACKET VS PAYLOAD? 

# PROBLEM: 
# We need to read, aggregate, filter, and JSON-ify the Bluethooth data to make it useful
# RasPi gathers BLE data by running two commands simultaneously: `hcitool` and `hcidump`. 
# The output from hcitool is a list of BLE device IDs and labels, but no data.
# The output from hcidump is a timestamp followed by raw BLE data packets. 
#
# Here's sample output of device IDs and labels from hcitool: 
# 1E:91:E8:B0:AF:DA (unknown)
# 88:C6:26:CA:42:47
# 7C:64:56:36:1F:D9 (unknown)
# 2C:41:A1:03:20:5D LE-QC 35 V2
# B0:34:95:38:82:5D (unknown)
# 88:C6:26:CA:42:47 (unknown)
# D4:A1:BD:1F:46:F2 (unknown)
# 21:D6:07:DF:B1:04 (unknown)
# 
# We don't care about most of the devices in this output -- which is why we need to filter data.
# The device ID `D4:A1:BD:1F:46:F2` is a Fujitsu beacon -- we need its data. 
# This bash script just discards the output from hcitool  
# We only use hcitool because hcidump won't work without hcitool. 
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
# Again, our BLE scanner picks up tons of devices. We need to filter down this output to the Fujitsu devices we care about. 
# In raw format, the Fujitsu device ID D4:A1:BD:1F:46:F2 becomes inverted to `F2 46 1F BD A1 D4` (shown above)
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
# (3) Outputs a JSON with the timestamp and data packet: Fujitsu beacon device ID (we call them tags), measurement data, and other junk data. 
#
# The function `read_blescan_packet_dump` does step (1)
# The function `process_and_filter_fujitsu_packets` does steps (2) and (3)
# There's a separate Ruby script that uses those JSONs as input, processes the measurement data from bytes to meaningful decimal values, and sends the values to Google Cloud 
# 


# begin BLE scanning
start_hcitool_lescan() {
  sudo hcitool lescan > /dev/null &
  # > /dev/null = throw away the data stream 
  # &           = run this in the background
  sleep 2
  # pause for 2 seconds to let hcitool start running before starting hcidump 
}

# Kill the hcitool process. We need to do this explicitly since it's running in the background. 
halt_hcitool_lescan() {
  sudo pkill --signal SIGINT hcitool
}

# Start dumping BLE packets using the `hcidump` utility and include the timestamp when the packet arrived 
start_hcidump_stream() {
  sudo hcidump -t --raw
}

# ??? To be more descriptive, could we rename this function filter_and_JSONify_fujitsu_packets 
# This function `process_and_filter_fujitsu_packets` receives a string from `read_blescan_packet_dump`: <packet contents>|<timestamp>  
# `process_and_filter_fujitsu_packets` returns a JSON-formatted string the Ruby script to process. 
process_and_filter_fujitsu_packets() {
  while read line; do
    # validate that the line is properly formatted (<packet contents>|<timestamp>)
    if [[ $line =~ ^(.*)\s+?\|\s+?(.*)$ ]]; then
      # Store the <packet contents> and <timestamp> in the variables packet and timestamp
      # We're working in Bash which sometimes causes a problem where extra blank spaces accidentally get loaded into variables
      # So we can't just assign the values directly: packet=${BASH_REMATCH[1]}
      # To fix this, we use `back ticks` to run the echo command which strips out any extra whitespace 
      local packet=`echo ${BASH_REMATCH[1]}`
      local timestamp=`echo ${BASH_REMATCH[2]}`
      # We check whether the packet is a Fujitsu BLE beacon by whether it contains 010003000300
      # If not, then we filter it out (no output). 
      # If it's the Fujitsu we're looking for, then we echo (output) the packet and timestamp as a JSON.
      [[ $packet =~ 010003000300 ]] && echo "{ \"timestamp\": \"$timestamp\", \"packet_data\": \"$packet\" }"
    fi
  done
}


# This function reads and assembles the packet because packets span multiple lines and need to be aggregated. 
# For example data from hcidump looks like this: 
# 2018-07-18 10:56:08.151507 > AA BB CC
# DD EE FF
# 11 22 33

# so the read_blescan_packet_dump function gathers the entire data packet without spaces or line breaks: AABBCCDDEEFF112233
# Read from an input stream that comes from `hcidump -t --raw` and return, for each packet, a string that
# looks like
#   <packet hex contents>|<timestamp>
# The result should be easily parseable into the packet contents and timestamp with a regex like ^(.*)\s+?\|\s+?(.*)$
# where the first match is the packet contents and the second is the timestamp string (2018-07-18 10:56:08.151507) 

# ??? Can we rename this function to aggregate_data_packet 
# The function `read_blescan_packet_dump` aggregates a data packet that breaks across lines
# The function outputs a complete packet and a timestamp 
read_blescan_packet_dump() {
  # As explained above, hcidump outputs raw BLE data packets that break across lines. 
  # We use a regex (regular expression) to identify a timestamp indicates the start of a transmission from a new BLE device  
  TIMESTAMP_REGEX="^([0-9]{4}-[0-9]{2}-[0-9]{2}.*)\s+>(.*)$"

  # start with an empty string
  packet=""

  # read a line 
  while read line; do
    new_transmission=0
    # check if the line contains our regex (timestamp) indicating that it's the beginning of a new trasnmission from a BLE device 
    [[ $line =~ $TIMESTAMP_REGEX ]] && new_transmission=1

      # store the values from the regex in the temporary variables for timestamp and packet, tmp_timestamp and tmp_packet 
      tmp_timestamp=${BASH_REMATCH[1]}
      tmp_packet=${BASH_REMATCH[2]}

    # if it's not a new transmission, then add the new line to the previous packet we already started
    if [[ $new_transmission == 0 ]]; then  
      # continue building the packet
      packet="$tmp_packet $line"

    # otherwise it is a new transmission, so we need to output the previous packet and start a new packet   
    else
      # check that the previous packet isn't empty 
      if [ "$packet" ]; then
        # remove > and whitespace from packet 
        clean_packet=${packet//[\ |>]/}
        # output <packet> | <timestamp> 
        echo $clean_packet "|" $timestamp
      fi

      # start the new packet
      timestamp=$tmp_timestamp
      packet=$tmp_packet
    fi
  done
}

######
# This is a library of functions that Mike and Jon created for `tag_scanner.sh` and other bash scripts that need to read BLE data
# This bash script includes several functions that help with scanning the BLE packets floating around in the ether.
#
# To use the bash script, you must have the `bluez` and `bluez-hcidump` packages installed on the RasPi 


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

# This function `filter_and_JSONify_fujitsu_packets` receives a string from `aggregate_data_packet`: <packet contents>|<timestamp>  
# `filter_and_JSONify_fujitsu_packets` returns a JSON-formatted string the Ruby script to process. 
filter_and_JSONify_fujitsu_packets() {
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

# As explained above, hcidump outputs raw BLE data packets that break across lines. 
# We use a regex (regular expression) to identify a timestamp that indicates the start of a new trasnmission from a BLE device 
TIMESTAMP_REGEX="^([0-9]{4}-[0-9]{2}-[0-9]{2}.*)\s+>(.*)$"


# The function `aggregate_data_packet` aggregates a data packet that breaks across lines
# The function outputs a complete packet and a timestamp 
aggregate_data_packet() {
  # start with an empty string(?)
  packet=""
  # read a line 
  while read line; do

    # check if the `line` contains our `TIMESTAMP_REGEX`, which indicates the start of a new trasnmission from a BLE device 
    # we extract values from the `line` and temporarily store them in `tmp_timestamp` and `tmp_packet` 
    # if the line is not the beginning of a new transmission, then the line is a continuation of the previous line, 
    #  so add the `line` to the previous `packet` we already started
    # if the line contains a new transmission, then we output the previous `packet`. 
    #  Then start a new packet by setting `packet`=`tmp_packet` and `timestamp`=`tmp_timestamp`
  
    if [[ $line =~ $TIMESTAMP_REGEX ]]; then
      # extract the regex matches immediately
      tmp_timestamp=${BASH_REMATCH[1]}
      tmp_packet=${BASH_REMATCH[2]}

      if [ "$packet" ]; then
        # remove > and whitespace from packet string
        clean_packet=${packet//[\ |>]/}
        # output the previous packet 
        echo $clean_packet "|" $timestamp
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

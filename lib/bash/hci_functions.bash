######
# This bash script includes several functions that help with scanning the BLE packets floating around in the ether.
#
# To use these, you must have the `bluez` and `bluez-hcidump` packages installed
#

# begin BLE scanning
# run output to the trash (/dev/null -- throw away the data stream)
# & run this in the background
start_hcitool_lescan() {
  sudo hcitool lescan > /dev/null &
  sleep 2
}

# Kill the hcitool process
halt_hcitool_lescan() {
  sudo pkill --signal SIGINT hcitool
}

# Start dumping BLE packets using the `hcidump` utility
start_hcidump_stream() {
  sudo hcidump -t --raw
}

# Given a string like <packet contents>|<timestamp> (from read_blescan_packet_dump)
# return a json formatted string for easier consumption outside of this function
process_and_filter_fujitsu_packets() {
  # take the first argument, $1, and set it to be the packet variable
  # also, in the packet: find any character that is "\ " (escape-character white space) or ">" (a greater than character).
  # Replace those characters with nothing -- because there's nothing in the first two slashes "//"
  while read line; do
    # if this line is properly formatted (<packet contents>|<timestamp>)
    if [[ $line =~ ^(.*)\s+?\|\s+?(.*)$ ]]; then
      # then save matches (and trim whitespace with the echo) and return a JSON formatted string with the data
      local packet=`echo ${BASH_REMATCH[1]}`
      local timestamp=`echo ${BASH_REMATCH[2]}`
      # if this matches a fujitsu packet, echo the json
      [[ $packet =~ 010003000300 ]] && echo "{ \"timestamp\": \"$timestamp\", \"packet_data\": \"$packet\" }"
    fi
  done
}

# This function reads and assembles the packet because packets span multiple lines and need to be built up
# This function is unclear -- Mike and Jon to discuss

WITH_TIMESTAMP_REGEX="^([0-9]{4}-[0-9]{2}-[0-9]{2}.*)\s+>(.*)$"

# Read from an input stream that comes from `hcidump -t --raw` and return, for each packet, a string that
# looks like
#   <packet hex contents>|<timestamp>
# The result should be easily parseable into the packet contents and timestamp with a regex like ^(.*)\s+?\|\s+?(.*)$
# where the first match is the packet contents and the second is the timestamp string (2018-07-18 10:56:08.151507)
read_blescan_packet_dump() {

  # start with an empty string(?)
  packet=""
  # read a line and look for the starting character ">" or with timestamp like "2018-07-18 10:56:08.151507 >"
  while read line; do
    # packets start with ">" ### Mike got lost here. Are we actually looking for the beginning of the *next* packet??
    if [[ $line =~ $WITH_TIMESTAMP_REGEX ]]; then
      # extract the regex matches immediately
      tmp_timestamp=${BASH_REMATCH[1]}
      tmp_packet=${BASH_REMATCH[2]}

      if [ "$packet" ]; then
        # remove > and whitespace from packet string
        clean_packet=${packet//[\ |>]/}
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

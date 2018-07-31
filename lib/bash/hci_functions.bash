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

# As explained above, hcidump outputs raw BLE data packets that break across lines.
# We use a regex (regular expression) to identify a timestamp that indicates the start of a new trasnmission from a BLE tag
TIMESTAMP_REGEX="^([0-9]{4}-[0-9]{2}-[0-9]{2}.*)\s+>(.*)$"

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

    # check if the `line` contains our `TIMESTAMP_REGEX`, which indicates the start of a new trasnmission from a BLE tag
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

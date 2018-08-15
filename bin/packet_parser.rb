#!/usr/bin/env ruby

# This Ruby program receives hex data from the `tag_scanner.sh` shell script and sends it to Google Cloud
# Comments in `tag_scanner.sh` detail this project.
#
# PROLBEM and SOLUTION that this Ruby script solves
# `tag_scanner.sh` delivers individual `input_payload` with a data packet and timestamp
# By default, the Fujistu beacons broadcast their status 1 time per second,
# so tag_scanner will deliver `input_payload` JSONs at a rate of (1 time per second) x (# of beacons nearby).
# We tried sending each measurement directly to the internet, but we encountered timeout errors
# To mitigate time outs, this script bundles the data packets, as determined by the user.
# For our test setup with 5 beacons, we found a good balance with BUNDLE_SIZE = 1,000 data packets
#
# The data packets come from the Fujitsu tags and arrive in this format (without spaces).
# Here's real sample data for three Fujitsu beacons:
#  1               2                     3                         4   5    6    7   8
# 043E2102010301 1C0CB35CBBD5 15 0201 04 11FF5900 0100 0300 0300 7F03 A503 C4FF A907 C3
# 043E2102010301 F2461FBDA1D4 15 0201 04 11FF5900 0100 0300 0300 4C03 6100 BDFF 0F08 CA
# 043E2102010301 71BF99DC8CF7 15 0201 04 11FF5900 0100 0300 0300 F904 8D00 5800 1E08 C4
# where:
# 1 = prefix. we don't really know what this does, but we're not throwing it out yet
# 2 = a unique ID for the Fujitsu tag which is inverted (AB:CD:EF:GH arrives as GH:EF:CD:AB) so we need to un-invert it.
#     So `1C0CB35CBBD5` above is actually Tag ID `D5BB 5CB3 0C1C`
# 4 = temperature measurement
# 5 = x-axis acceleration
# 6 = y-axis acceleration
# 7 = z-axis acceleration
# 8 = RSSI
# Note that temp and acceleration are inverted and 2-bytes long (16 bits) in two's compliment format. https://www.cs.cornell.edu/~tomf/notes/cps104/twoscomp.html
# Fujitsu's documentation explains how to calculate convert the data packet to real temp and acceleration values.
#

# Use the bundler library to get external libraries from the internet
require "bundler"

# Require other ruby system libraries
require "json"
require "io/console"

# require local ruby helpers and classes, which we made for this project
lib_dir = "../lib/ruby"
require_relative "#{lib_dir}/measurement.rb"
require_relative "#{lib_dir}/google_cloud_storage_service.rb"
require_relative "#{lib_dir}/packet_decoder.rb"

# Setup Logger
require "logger"

logfile = File.open("logs/packet_parser.log", File::WRONLY | File::APPEND | File::CREAT)
log = Logger.new(logfile)
log.level = Logger.const_get(ENV.fetch("LOG_LEVEL", "WARN").upcase)
log.datetime_format = "%Y-%m-%d %H:%M:%S"
log.info "Started Parsing Packets"

### *** THE MAIN SCRIPT ***

# The raw Fujitsu data will arrive in this regular expression (REGEX); sample data is in the comments above
# We define the <names> and {number of characters} for each part of the REGEX
PACKET_DATA_REGEX = %r{^(?<prefix>.{14})(?<tag_id>.{12})15020104(?<unused>.{8})010003000300(?<temperature>.{4})(?<x_acc>.{4})(?<y_acc>.{4})(?<z_acc>.{4})(?<rssi>.{2})$}

# Each version of this project has it's own unique `env.sh` file that contains personal secret credentials to run this project
# Before starting this shell script, the user must run `source env.sh` to include env.sh in the Unix environmental variables (ENV.fetch("...")).
# These variables allow us to send data to our Google Project
GOOGLE_PROJECT_ID = ENV.fetch("GOOGLE_PROJECT_ID")
GOOGLE_CREDENTIALS_JSON = ENV.fetch("GOOGLE_CREDENTIALS_JSON_FILE")
# our defaults values are "dream-assets-orange" and "measurements"
GOOGLE_BUCKET = ENV.fetch("GOOGLE_BUCKET", "dream-assets-orange")
GOOGLE_BUCKET_DIRECTORY = ENV.fetch("GOOGLE_BUCKET_DIRECTORY", "measurements")
# set the hub_id to the hostname of the Raspberry Pi
HUB_ID = ENV.fetch("HUB_ID", `hostname`.chomp)


log.debug("Build Google Service")

# this is our service wrapper as defined in our library google_cloud_storage_service.rb
google_storage_client = GoogleCloudStorageService.new(
  GOOGLE_PROJECT_ID,
  GOOGLE_CREDENTIALS_JSON,
  HUB_ID,
  GOOGLE_BUCKET,
  directory: GOOGLE_BUCKET_DIRECTORY
)

# This Ruby script stores data packets in memory (RAM) `measurement_bundle` on the hub (Raspberry Pi)
# before sending a complete bundle off to Google Cloud Storage
measurement_bundle = []

# Set the bundle size, which defaults to 100 if it's not specified.
BUNDLE_SIZE = ENV.fetch("BUNDLE_SIZE", 100).to_i

log.debug("Current Settings: HUB BUNDLE_SIZE #{BUNDLE_SIZE}")
log.debug("Current Settings: GOOGLE BUCKET #{GOOGLE_BUCKET}")
log.debug("Current Settings: GOOGLE DIRECTORY #{GOOGLE_BUCKET_DIRECTORY}")
log.debug("Start Processing input data")

# Setup upload clients for Google Storage
upload_clients = [google_storage_client]

# This code only uses one client (Google Cloud) but
# `upload_to_all_clients` allows us to send data to other clients easily
def upload_to_all_clients(clients, measurement_bundle, logger)
  clients.each do |client|
    logger.info("Sending to #{client.class.name}")
    client.upload(measurement_bundle)
  end
rescue StandardError => ex
  logger.error("Something went wrong : #{ex}")
  logger.debug(ex.backtrace)
end

# Each line is an `input_payload` that contains a packet of data (`packet_data`) and a time stamp (`timestamp`).
while line = gets
  next unless line
  line.chomp!
  begin
    # we tell Ruby to parse the line as a JSON
    input_payload = JSON.parse(line)

    # `tag_scanner.sh` filters out any data packet that isn't from Fujitsu. Nonetheless, here we doublecheck
    #  that there's data in packet_data and that it matches the Fujitsu Regex
    decoded_packet = PacketDecoder.decode(input_payload["packet_data"])
    next unless decoded_packet

    # put all the data in a new measurement
    # as soon as the Measurement class gets the hex input variables, it converts them to meaningful values (floats/integers)
    measurement = Measurement.new(**decoded_packet.merge(hub_id: HUB_ID, timestamp: input_payload["timestamp"]))

    # echo the new measurement to the console in CSV format -- this is purely informational
    $stdout.puts measurement.csv_row

    # Store the measurement in the bundle
    measurement_bundle << measurement

    # if the bundle is big enough, push the data to Google Storage. Then start a new bundle
    if measurement_bundle.length >= BUNDLE_SIZE
      log.info "Got a full bundle of (#{BUNDLE_SIZE} measurements)"
      upload_to_all_clients(upload_clients, measurement_bundle, log)
      measurement_bundle = []
    end

  # if there's a problem with the line (e.g., it's not JSON, whatever),
  # just let us know there's a problem and continue on to the next line. Don't blow up :)
  rescue JSON::ParserError => ex
    log.error("Failed to parse json #{ex}")
    # ignore line if we can't parse it
  end
end

log.info "Hit the end of the stream."
# finally send whatever we might have left if we get to the end of the input data stream
if !measurement_bundle.empty?
  log.info "Sending the remaining #{measurement_bundle.length} measurements"
  upload_to_all_clients(upload_clients, measurement_bundle, log)
end

#!/usr/bin/env ruby

# This Ruby program receives hex data from a shell script and sends it to the interwebs
# The data comes in this format:
#  1               2                     3                        4   5    6    7   8
# 043E2102010301 1C0CB35CBBD5 15 0201 04 11FF5900 0100 0300 0300 7F03 A503 C4FF A907 C3
# 043E2102010301 F2461FBDA1D4 15 0201 04 11FF5900 0100 0300 0300 4C03 6100 BDFF 0F08 CA
# 043E2102010301 71BF99DC8CF7 15 0201 04 11FF5900 0100 0300 0300 F904 8D00 5800 1E08 C4
# where:
# 1 = prefix. we don't really know what this does, but we're not throwing it out yet
# 2 = a unique ID for the Fujitsu tag which is inverted (AB:CD:EF:GH arrives as GH:EF:CD:AB) so we need to un-invert it.
# 4 = temperature measurement
# 5 = x-axis acceleration
# 6 = y-axis acceleration
# 7 = z-axis acceleration
# 8 = RSSI
# Note that temp and acceleration are inverted and 2-bytes long (16 bits) in two's compliment format. https://www.cs.cornell.edu/~tomf/notes/cps104/twoscomp.html


# Use the bundler library to get external libraries from the internet
require 'bundler/inline'

# go on the internet and get the DataDog api gem
gemfile(true) do
  source "https://rubygems.org"
  gem "aws-sdk-s3", '~> 1'
  gem "google-cloud-storage"
end

# Require other ruby system libraries
require 'json'
require 'io/console'

# require local ruby helpers and classes
require_relative "./lib/measurement.rb"
require_relative "./lib/s3_service.rb"
require_relative "./lib/google_cloud_storage_service.rb"

# Setup Logger
require 'logger'

logfile = File.open('logs/packet_parser.log', File::WRONLY | File::APPEND | File::CREAT)
log = Logger.new(logfile)
log.level = Logger.const_get(ENV.fetch("LOG_LEVEL", "WARN").upcase)
log.datetime_format = "%Y-%m-%d %H:%M:%S"
log.info "Started Parsing Packets"

### *** THE MAIN SCRIPT ***

# set the hub_id to the hostname
HUB_ID = `hostname`.chomp

# The raw Fujitsu data will arrive in this regular expression (REGEX)
# We define the <names> and {number of characters} for each part of the REGEX
PACKET_DATA_REGEX = %r{^(?<prefix>.{14})(?<tag_id>.{12})15020104(?<unused>.{8})010003000300(?<temperature>.{4})(?<x_acc>.{4})(?<y_acc>.{4})(?<z_acc>.{4})(?<rssi>.{2})$}

# grab variables from the environemnt
BUNDLE_SIZE = ENV.fetch("BUNDLE_SIZE", 100).to_i
S3_BUCKET = ENV.fetch("S3_BUCKET", "dream-assets-orange")
S3_BUCKET_DIRECTORY = ENV.fetch("S3_BUCKET_DIRECTORY", "measurements")

GOOGLE_PROJECT_ID=ENV.fetch("GOOGLE_PROJECT_ID")
GOOGLE_CREDENTIALS_JSON="./secrets/DreamAssetTester-321cb537c48c.json"
GOOGLE_BUCKET=S3_BUCKET
GOOGLE_BUCKET_DIRECTORY=S3_BUCKET_DIRECTORY

log.debug("Build S3 Service")

s3_client = S3Service.new(
  HUB_ID,
  S3_BUCKET,
  directory: S3_BUCKET_DIRECTORY
)
google_storage_client = GoogleCloudStorageService.new(
  GOOGLE_PROJECT_ID,
  GOOGLE_CREDENTIALS_JSON,
  HUB_ID,
  GOOGLE_BUCKET,
  directory: GOOGLE_BUCKET_DIRECTORY
)

measurement_bundle = []

# get all the text up to a carriage return. Store that text in `line` and throw out the return.

log.debug("Start Processing input data")

# Setup upload clients
upload_clients = [ s3_client, google_storage_client ]

def upload_to_all_clients(clients, measurement_bundle, logger)
  begin
    clients.each do |client|
      logger.info("Sending to #{client.class.name}")
      client.upload(measurement_bundle)
    end
  rescue Exception => ex
    logger.error("Something went wrong : #{ex}")
    raise ex
  end
end

while line = gets do
  next unless line
  line.chomp!
  begin
    # we're expecting the line of data to arrive in a JSON format, so we tell Ruby to parse it as a JSON
    packet_data = JSON.parse(line)
  # if there's a problem with the line (e.g., it's not JSON, whatever), just let us know there's a problem and continue on to the next line. Don't blow up :)
  rescue JSON::ParserError => ex
    log.error("Failed to parse json #{ex}")
    # ignore line if we can't parse it
  end

  # check that there's data in packet_data and that it matches the Fujitsu Regex, since we'll get lots of irrelevant BLE packets
  if (packet_data && (match = PACKET_DATA_REGEX.match(packet_data["packet_data"])))
    timestamp = packet_data["timestamp"]
    tag_id = match[:tag_id]
    temperature = match[:temperature]
    x_acc = match[:x_acc]
    y_acc = match[:y_acc]
    z_acc = match[:z_acc]
    rssi = match[:rssi]

    # put all the data in a new measurement
    measurement = Measurement.new(
      hub_id: HUB_ID,
      timestamp: timestamp,
      tag_id: tag_id,
      hex_temperature: temperature,
      hex_x_acc: x_acc,
      hex_y_acc: y_acc,
      hex_z_acc: z_acc,
      hex_rssi: rssi)
    # echo the new measurement to the console in CSV format -- this is purely informational
    $stdout.puts measurement.csv_row

    measurement_bundle << measurement

    # if the bundle is big enough, push the data to the cloud and start a new bundle
    if measurement_bundle.length >= BUNDLE_SIZE
      log.info "Got a full bundle (#{BUNDLE_SIZE} measurements)"
      upload_to_all_clients(upload_clients, measurement_bundle, log)
      measurement_bundle = []
    end
  end
end

log.info "Hit the end of the stream."
# finally send whatever we might have left if we get to the end of the input data stream
if measurement_bundle.length > 0
  log.info "Sending the remaining #{measurement_bundle.length} measurements"
  upload_to_all_clients(upload_clients, measurement_bundle, log)
end


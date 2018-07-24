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
  gem "dogapi"
  gem "aws-sdk-s3", '~> 1'
end

# Require other ruby system libraries
require 'json'
require 'io/console'

# require local ruby helpers and classes
require_relative "./lib/measurement.rb"
require_relative "./lib/data_dog_service.rb"
require_relative "./lib/s3_service.rb"

### *** THE MAIN SCRIPT ***

# set the hub_id to the hostname
hub_id = `hostname`.chomp

# The raw Fujitsu data will arrive in this regular expression (REGEX)
# We define the <names> and {number of characters} for each part of the REGEX
PACKET_DATA_REGEX = %r{^(?<prefix>.{14})(?<tag_id>.{12})15020104(?<unused>.{8})010003000300(?<temperature>.{4})(?<x_acc>.{4})(?<y_acc>.{4})(?<z_acc>.{4})(?<rssi>.{2})$}

# Get the DataDog key from my Unix environment (env)
DATADOG_API_KEY = ENV["DATADOG_API_KEY"]

# This code allows the hub to run without sending data to DataDog. Without this if(), the code would break and we wouldn't know why.
datadog_client = nil
if (DATADOG_API_KEY)
  datadog_client = DataDogService.new(DATADOG_API_KEY)
else
  # If there's an error wit the API key, echo say so on the console
  $stderr.puts "*** Not sending data to DataDog because there is no api key.  Please set DATADOG_API_KEY in your environment ***"
end

s3_client = S3Service.new("dream-assets-orange")

# get all the text up to a carriage return. Store that text in `line` and throw out the return.
while line = gets do
  next unless line
  line.chomp!
  begin
    # we're expecting the line of data to arrive in a JSON format, so we tell Ruby to parse it as a JSON
    packet_data = JSON.parse(line)
  # if there's a problem with the line (e.g., it's not JSON, whatever), just let us know there's a problem and continue on to the next line. Don't blow up :)
  rescue JSON::ParserError => ex
    puts "ERROR #{ex}"
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
      hub_id: hub_id, 
      timestamp: timestamp, 
      tag_id: tag_id,  
      hex_temperature: temperature, 
      hex_x_acc: x_acc, 
      hex_y_acc: y_acc, 
      hex_z_acc: z_acc, 
      hex_rssi: rssi)
    # echo the new measurement to the console in CSV format -- this is purely informational
    $stdout.puts measurement.csv_row

    # send the new measurement to DataDog -- this is where the data goes from the Hub to the Cloud
    begin
      # if `datadog_client` isn't null then run the send_measurement() method on datadog_client, which is tied to our API key,
      datadog_client.add_measurement(measurement) if datadog_client
      s3_client.add_measurement(measurement) if s3_client
    rescue SocketError => socket_exception
      $stderr.puts "Socket Errror #{socket_exception}... ignoring for now"
    rescue Net::OpenTimeout => network_timeout_exception
      # we've had a problem where the server takes a while, so if that happens, just ignore the timeout
      $stderr.puts "Network Timeout #{network_timeout_exception}... ignoring for now"
    end
  end
end

# Finally
# if we didn't get a full bundle, send what we have
datadog_client.send_and_reset_bundle if datadog_client
s3_client.send_and_reset_bundle if s3_client

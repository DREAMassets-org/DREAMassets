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
gemfile do
  source "https://rubygems.org"
  gem "dogapi"
end

# Require other ruby system libraries
require 'json'
require 'io/console'


# this module converts data from a binary twos complement into a signed integer
# this module expects the binary to be 16-bits long, which is what the Fujitsu provides
# https://www.cs.cornell.edu/~tomf/notes/cps104/twoscomp.html
module TwosComplement
  def convert_to_signed_binary(binary)
    binary_int = binary.to_i(2)
    if binary_int >= 2**15
      return binary_int - 2**16
    else
      return binary_int
    end
  end

  def translate_to_binary(num)
    sprintf("%b", num).rjust(32, '0')
  end
end

# Class that stores packet information in an easily accessible structure
class Packet

  include TwosComplement

  # The acceleration values are floating point with 3 significant digits.
  # This is our arbitrary decision -- we could have more sigfigs but this works for now.
  ACCELERATION_FORMAT = "%2.3f"

  # Our `Packet` class has attributes timestamp, prefix, etc.
  # the method attr_reader allows us to access the attributes from outside the Packet class
  attr_reader :timestamp, :prefix, :device_id, :temperature, :x_acceleration, :y_acceleration, :z_acceleration, :rssi

  # Packet expects to receive a data packet in hex format, which we conver to meaningful decimal values, according to Fujitsu's formulas
  def initialize(timestamp, prefix, device_id, hex_temperature, hex_x_acc, hex_y_acc, hex_z_acc, hex_rssi)

    # note to selves: for now, we're processing the fujitsu bytes into meaninful values
    # in the future, when we get a cloud server, it prolly'll make sense to do that processing in the cloud

    # set `timestamp` to the time-formatted time object
    # Time is a ruby class that has a `parse` method which converts a string to a time-formatted object
    @timestamp = Time.parse(timestamp)
    @prefix = prefix

    # the device ID is inverted (AB:CD:EF:GH arrives as GH:EF:CD:AB) so we need to un-invert it using flip_bytes().
    @device_id = flip_bytes(device_id)
    # we're assuming that RSSI for Fujitsu beacons is similar to iBeacons
    @rssi = hex_rssi.to_i(16) - 256
    # take the acceleration value, flip the bytes, and run Fujitsu's formula to get fractions of 1g:
    @x_acceleration = acceleration( flip_bytes(hex_x_acc) )
    @y_acceleration = acceleration( flip_bytes(hex_y_acc) )
    @z_acceleration = acceleration( flip_bytes(hex_z_acc) )
    # Fujitsu provided the formula to convert a temperature value in two's compliment hex to degC:
    # Hex -> signed_int / 333.87 + 21.0 = degC
    # Since we're in 'Merica we put temperature in degF = degC * 9/5 + 32
    @temperature = (((unpack_value( flip_bytes(hex_temperature) ) / 333.87) + 21.0) * 9.0 / 5.0) + 32

  end

  # When we visualize the data in the RPi terminal, we use CSV format
  def csv_row
    [
      device_id,
      "%2.2f" % temperature,
      ACCELERATION_FORMAT % x_acceleration,
      ACCELERATION_FORMAT % y_acceleration,
      ACCELERATION_FORMAT % z_acceleration,
      rssi,
      timestamp
    ].join(",")
  end

  # methods below are not accessible outside the Packet class; they're private
  private

  def flip_bytes(hex_bytes)
    hex_bytes.split("").each_slice(2).map(&:join).reverse.join
  end

  def acceleration(hex_string)
    unpack_value(hex_string) / 2048.to_f
  end

  # unpack_value() takes a hex value and returns a signed float
  # first take the string (0x000F) and turn it into an integer (15) using .to_i(base) where the input is base 16
  # next translate that integer (15) to a binary (0000 0000 0000 1111)
  # convert_to_signed_binary() then sees whether the first bit is positive (0) or negative (1)
  # if the first bit is '0' then it's unsigned -> therefore no change
  # if the first bit is '1' then it's signed, so do the two's compliment to get the integer equivalent.
  # for instance 1111 1111 1111 1101 is -3 in two's compliment
  # finally convert that value to a floating point number
  # https://www.exploringbinary.com/twos-complement-converter/
  # https://www.cs.cornell.edu/~tomf/notes/cps104/twoscomp.html
  def unpack_value(hex_string)
    convert_to_signed_binary(translate_to_binary(hex_string.to_i(16))).to_f
  end

end

# DataDog is our cloud storage and visualisation platform
class DataDog

  HOSTNAME = `hostname`

  DATA_BUNDLE_SIZE = 100

  # We need to give DataDog our API key so they know it's us sending data
  def initialize(api_key)
    @api_key = api_key
    @events = []
  end

  def add_event(packet)
    @events << packet
    if @events.length >= DATA_BUNDLE_SIZE
      send_and_reset_events
    end
  end

  def send_and_reset_events
    %i( x_acceleration y_acceleration z_acceleration temperature rssi ).each do |metric|
      data_by_device_id = @events.each_with_object({}) do |event, obj|
        obj[event.device_id] ||= []
        obj[event.device_id] << [ event.timestamp, event.send(metric) ]
      end
      data_by_device_id.each do |device_id, datapoints|
        client.emit_points("fujitsu.#{metric}", datapoints, host: HOSTNAME, device: device_id)
        #puts "sent to datadog #{device_id} : #{datapoints}"
      end
    end
    @events = []
  end

  # this send_event() is specific to DataDog. If we use a difference cloud, we'd build a new class and change/customize send_event()
  def send_event(packet)
    # DataDog can only receive data in this format: key : value, where value is (time, metric)
    # metric = temp, x_accel, etc. We send data to DataDog for each metric
    # key = "fujistu.#{metric}"
    # value = time, value of the metric
    # metadata is used for filtering. For our project, metadata is host and device
    # Examples of what we send:
    # { "fujitsu.temperature" : 1532112674, 72.0, host: `reve`, device: AB:CD:EF:GH}
    # { "fujitsu.x_acceleration" : 1532112674, 0.034, host: `reve`, device: AB:CD:EF:GH}
    # { "fujitsu.z_acceleration" : 1532112674, -1.012, host: `reve`, device: AB:CD:EF:GH}
    %i( x_acceleration y_acceleration z_acceleration temperature rssi ).each do |metric|
      client.emit_points("fujitsu.#{metric}", [[packet.timestamp, packet.send(metric)]], host: HOSTNAME, device: packet.device_id)
    end
  end

  # client is the destination where we send our data. Client is a wrapper for a URL where we send our data
  private
  def client
    @client ||= Dogapi::Client.new(@api_key)
  end
end

### *** THE MAIN SCRIPT ***

# packets is an empty array
packets = []

# The raw Fujitsu data will arrive in this regular expression (REGEX)
# We define the <names> and {number of characters} for each part of the REGEX
PACKET_DATA_REGEX = %r{^(?<prefix>.{14})(?<device_id>.{12})15020104(?<unused>.{8})010003000300(?<temperature>.{4})(?<x_acc>.{4})(?<y_acc>.{4})(?<z_acc>.{4})(?<rssi>.{2})$}

# Get the DataDog key from my Unix environment (env)
DATADOG_API_KEY = ENV["DATADOG_API_KEY"]

# This code allows the hub to run without sending data to DataDog. Without this if(), the code would break and we wouldn't know why.
datadog_client = nil
if (DATADOG_API_KEY)
  datadog_client = DataDog.new(DATADOG_API_KEY)
else
  # If there's an error wit the API key, echo say so on the console
  $stderr.puts "*** Not sending data to DataDog because there is no api key.  Please set DATADOG_API_KEY in your environment ***"
end

# get all the text up to a carriage return. Store that text in `line` and throw out the return.
while line = gets&.chomp do
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
    # load the packet variables with data
    timestamp = packet_data["timestamp"]
    prefix = match[:temperature]
    device_id = match[:device_id]
    temperature = match[:temperature]
    x_acc = match[:x_acc]
    y_acc = match[:y_acc]
    z_acc = match[:z_acc]
    rssi = match[:rssi]
    # put all the data in a new packet
    packet = Packet.new(timestamp, prefix,  device_id,  temperature,  x_acc, y_acc,  z_acc, rssi)
    # echo the new packet to the console in CSV format -- this is purely informational
    $stdout.puts packet.csv_row

    # send the new packet to DataDog -- this is where the data goes from the Hub to the Cloud
    begin
      # if `datadog_client` isn't null then run the send_event() method on datadog_client, which is tied to our API key,
      datadog_client && datadog_client.add_event(packet)
    rescue Net::OpenTimeout
      # we've had a problem where the server takes a while, so if that happens, just ignore the timeout
      puts "Network Timeout... ignoring for now"
    end

  end
end

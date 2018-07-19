#!/usr/bin/env ruby
# the line above allows this ruby program to run from the command line

# The bash script tag_scanner.sh pipes date into this ruby program in the format `timestamp` and data `packet`
# The data packet is a hexadecimal string without spaces that looks like this:  
#  1               2                     3                        4   5    6    7   8
# 043E2102010301 1C0CB35CBBD5 15 0201 04 11FF5900 0100 0300 0300 7F03 A503 C4FF A907 C3
# 043E2102010301 F2461FBDA1D4 15 0201 04 11FF5900 0100 0300 0300 4C03 6100 BDFF 0F08 CA
# 043E2102010301 71BF99DC8CF7 15 0201 04 11FF5900 0100 0300 0300 F904 8D00 5800 1E08 C4
# where:
# 2 = a unique ID for the Fujitsu tag which is inverted (AB:CD:EF:GH arrives as GH:EF:CD:AB) so we need to un-invert it. 
# 4 = temperature measurement
# 5 = x-axis acceleration
# 6 = y-axis acceleration
# 7 = z-axis acceleration
# 8 = RSSI 
# Note that temp and acceleration are all 2-bytes long (16 bits) in two's compliment format. https://www.cs.cornell.edu/~tomf/notes/cps104/twoscomp.html 

# Requiring packages we rely on 
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

# `Packet` is a class that stores information for a data packet in an easily accessible structure
class Packet

  include TwosComplement

  # The acceleration values are floating point with 3 significant digits. 
  # This is our arbitrary decision -- we could have more sigfigs but this works for now. 
  ACCELERATION_FORMAT = "%2.3f"

  # Our `Packet` class has attributes timestamp, prefix, etc.
  # the method attr_reader allows us to access the attributes from outside the Packet class 
  # Note that the hex_rssi attribute *is not* included in this list since it should never be accessed from outside 
  attr_reader :timestamp, :prefix, :uuid, :hex_temperature, :hex_x_acc, :hex_y_acc, :hex_z_acc, :rssi

  # When we create a new packet by saying Packet.new() we expect to receive all of these arguments 
  def initialize(timestamp, prefix, uuid, hex_temperature, hex_x_acc, hex_y_acc, hex_z_acc, hex_rssi)

    # we store both the original hex values (after byte flipping) and calculates the actual values of
    # acceleration and tempeature based on Fujitsu's provided math

    # First, get the arguments and load them into the Packet's attributes
    @timestamp = timestamp
    @prefix = prefix
    @uuid = uuid  # ??? Where do we flip the bytes for UUID? Why not flip here too? 
    # temp and acceleration data arrive with their bytes inverted (CD:AB) so we need to flip_bytes to get (AB:CD)
    @hex_temperature = flip_bytes(hex_temperature)
    @hex_x_acc = flip_bytes(hex_x_acc)
    @hex_y_acc = flip_bytes(hex_y_acc)
    @hex_z_acc = flip_bytes(hex_z_acc)
    # RSSI is only 1 byte, so no flipping needed 
    @hex_rssi = hex_rssi
    @rssi = hex_rssi.to_i(16) # let's process this 

    # run functions(?) that we define below
    temperature
    x_acceleration
    y_acceleration
    z_acceleration
  end # end initialize

  def csv_row # Are we going with CSV rows in the end? wasn't it JSON key:value pairs? 
    [
      uuid,
      "%2.2f degF" % temperature, # let's remove 
      ACCELERATION_FORMAT % x_acceleration,
      ACCELERATION_FORMAT % y_acceleration,
      ACCELERATION_FORMAT % z_acceleration,
      rssi,
      timestamp
    ].join(",")
  end

  # begin defining functions that are private, only accessible within the Packet class (???)
  private

  # get an argument with inverted bytes 0xCDAB and flip them to be 0xABCD
  def flip_bytes(bytes)
    bytes[2..3] + bytes[0..1]
  end

  # Fujitsu provided the formula to convert a hex value in two's compliment to degC: 
  # Hex -> signed_int / 333.87 + 21.0 = degC
  # Since we're in 'Merica we put temperature in degF = degC * 9/5 + 32
  def temperature
    @temperature ||= (((unpack_value(hex_temperature) / 333.87) + 21.0) * 9.0 / 5.0) + 32
  end

  # convert the x, y, and z acceleration values from hex to actual measurements
  def x_acceleration
    @x_acc ||= acceleration(hex_x_acc)
  end

  def y_acceleration
    @y_acc ||= acceleration(hex_y_acc)
  end

  def z_acceleration
    @z_acc ||= acceleration(hex_z_acc)
  end

  # Fujitsu provided the formula to convert a hex value in two's compliment to acceleration:   
  # Hex -> signed_int / 2048 = fractions of 1g
  # The tag will register -1g for the axis facing downward. 
  def acceleration(hex_string)
    unpack_value(hex_string) / 2048.to_f
  end

  # unpack_value takes a hex value and returns a signed float (???)
  # first take the string (0x000F) and turn it into an integer (15) using .to_i(base) where the number is base 16
  # next translate that integer (15) to a binary (0000 0000 0000 1111)
  # convert to signed binary then reads then looks at the first bit to see if it's signed or unsigned
  # if the first bit is '0' then it's unsigned -> therefore no change
  # if the first bit is '1' then it's signed, so do the two's compliment to get the integer equivalent.
  # for instance 1111 1111 1111 1101 is -3 in two's compliment 
  # finally convert that value to a floating point number 
  def unpack_value(hex_string)
    convert_to_signed_binary(translate_to_binary(hex_string.to_i(16))).to_f
  end

end # end class Packet 

# packets is an empty array (??)
packets = []

# We expect the data packets to arrive in a regular expression, as defined by Fujitsu
# Let's define these variables instead of relying on a count 
PACKET_DATA_REGEX = /^(.{14})(.{12})15020104(.{8})010003000300(.{4})(.{4})(.{4})(.{4})(.{2})$/

# ????
while line = gets&.chomp do
  begin
    packet_data = JSON.parse(line)
  rescue JSON::ParserError => ex
    puts "ERROR #{ex}"
    # ignore line if we can't parse it
  end

  if (packet_data && (PACKET_DATA_REGEX.match(packet_data["packet_data"])))
    timestamp = packet_data["timestamp"]
    # update to variables instead of $1, $2, etc. counts
    prefix = $1
    uuid_maybe = $2
    temperature = $4
    x_acc = $5
    y_acc = $6
    z_acc = $7
    rssi = $8

    #assemble a new packet 
    packet = Packet.new(timestamp, prefix,  uuid_maybe,  temperature,  x_acc, y_acc,  z_acc, rssi)

    # output the data packet as a CSV row. Why???
    $stdout.puts packet.csv_row

    # ???
    $stdout.ioflush
  end
end

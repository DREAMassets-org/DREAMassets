# This library contains methods and functions for packet_parser.rb and configurator.rb (and maybe other rb's)
#
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
    sprintf("%b", num).rjust(32, "0")
  end
end

# Class that stores Measurement information in an easily accessible structure
class Measurement
  include TwosComplement

  # The acceleration values are floating point with 5 significant digits.
  # This is our arbitrary decision -- we could have more sigfigs but this works for now.
  ACCELERATION_FORMAT = "%2.5f".freeze

  # Our `Measurement` class has attributes timestamp, prefix, etc.
  # the method attr_reader allows us to access the attributes from outside the Measurement class
  attr_reader :timestamp, :hub_id, :tag_id, :temperature, :x_acceleration, :y_acceleration, :z_acceleration, :rssi

  # Measurement expects to receive a data Measurement in hex format, which we conver to meaningful decimal values, according to Fujitsu's formulas
  def initialize(tag_id:, hex_temperature:, hex_x_acc:, hex_y_acc:, hex_z_acc:, hex_rssi:, hub_id: nil, timestamp: nil)
    # note to selves: for now, we're processing the fujitsu bytes into meaninful values in this script on the Raspberry Pi
    # in the future, it might make sense to do the processing in the cloud

    @hub_id = hub_id

    # set `timestamp` to the time-formatted time object
    # Time is a ruby class that has a `parse` method which converts a string to a time-formatted object
    @timestamp = Time.parse(timestamp) if timestamp

    # the tag ID is inverted (AB:CD:EF:GH arrives as GH:EF:CD:AB) so we need to un-invert it using flip_bytes().
    @tag_id = flip_bytes(tag_id)
    # we're assuming that RSSI for Fujitsu beacons is similar to iBeacons
    @rssi = hex_rssi.to_i(16) - 256
    # take the acceleration value, flip the bytes, and run Fujitsu's formula to get fractions of 1g:
    @x_acceleration = acceleration(flip_bytes(hex_x_acc))
    @y_acceleration = acceleration(flip_bytes(hex_y_acc))
    @z_acceleration = acceleration(flip_bytes(hex_z_acc))
    # Fujitsu provided the formula to convert a temperature value in two's compliment hex to degC:
    # Hex -> signed_int / 333.87 + 21.0 = degC
    # Since we're in 'Merica we put temperature in degF = degC * 9/5 + 32
    @temperature = (((unpack_value(flip_bytes(hex_temperature)) / 333.87) + 21.0) * 9.0 / 5.0) + 32
  end

  # To upload data to Google Cloud as well as to visualize the data in the RasPi terminal, we use CSV format
  def csv_row
    [
      hub_id,
      tag_id,
      "%2.2f" % temperature,
      ACCELERATION_FORMAT % x_acceleration,
      ACCELERATION_FORMAT % y_acceleration,
      ACCELERATION_FORMAT % z_acceleration,
      rssi,
      timestamp.to_i
    ].join(",")
  end

  # this definition might not be needed
  def as_json
    {
      tag_id: tag_id,
      temperature: temperature,
      x_acceleration: x_acceleration,
      y_acceleration: y_acceleration,
      z_acceleration: z_acceleration,
      rssi: rssi,
      timestamp: timestamp.to_i
    }
  end

  # methods below are not accessible outside the Measurement class; they're private
  private

  def flip_bytes(hex_bytes)
    hex_bytes.split("").each_slice(2).map(&:join).reverse.join
  end

  def acceleration(hex_string)
    # Fujitsu says to convert an acceleration mesurement in bytes to a meaningful decimal:
    # Bytes -> decimal using two's compliment.  Divide that value by 2048 to get fractions of 1g of acceleration.
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

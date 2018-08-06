# These functions help us decode the packet payload (as a hex string) into data

# The raw Fujitsu data will arrive in this regular expression (REGEX)
# We define the <names> and {number of characters} for each part of the REGEX

import re
import string
import math

PACKET_DATA_REGEX = re.compile(r'010003000300(?P<temperature>.{4})(?P<x_acc>.{4})(?P<y_acc>.{4})(?P<z_acc>.{4})$')

def decode(packet_hex_string):
  match=re.search(PACKET_DATA_REGEX, packet_hex_string or '')
  if not match:
    return

  hex_temperature = match.group('temperature')
  hex_x_acc = match.group('x_acc')
  hex_y_acc = match.group('y_acc')
  hex_z_acc = match.group('z_acc')

  return {
    'temperature': _compute_temperature(hex_temperature),
    'x_acc': _compute_acceleration(hex_x_acc),
    'y_acc': _compute_acceleration(hex_y_acc),
    'z_acc': _compute_acceleration(hex_z_acc)
  }

def each_slice(size, iterable):
    """ Chunks the iterable into size elements at a time, each yielded as a list.

    Example:
      for chunk in each_slice(2, [1,2,3,4,5]):
          print(chunk)

      # output:
      [1, 2]
      [3, 4]
      [5]
    """
    current_slice = []
    for item in iterable:
        current_slice.append(item)
        if len(current_slice) >= size:
            yield current_slice
            current_slice = []
    if current_slice:
        yield current_slice

def _flip_bytes(hex_bytes):
  return ''.join(map( lambda pr : ''.join(pr), each_slice(2, list(hex_bytes)))[::-1])

def _compute_temperature(hex_temperature):
  return (((_unpack_value(_flip_bytes(hex_temperature)) / 333.87) + 21.0) * 9.0 / 5.0) + 32

def _compute_acceleration(hex_accel):
  return _unpack_value(_flip_bytes(hex_accel)) / 2048.0

def _unpack_value(hex_string):
  value = int(hex_string,16)
  if value >= 2**15:
    return value - 2**16
  else:
    return value

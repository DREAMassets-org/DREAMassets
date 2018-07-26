# THis class helps us decode the packet payload (as a hex string) into data
class PacketDecoder
  # The raw Fujitsu data will arrive in this regular expression (REGEX)
  # We define the <names> and {number of characters} for each part of the REGEX
  PACKET_DATA_REGEX = %r{^(?<prefix>.{14})(?<tag_id>.{12})15020104(?<unused>.{8})010003000300(?<temperature>.{4})(?<x_acc>.{4})(?<y_acc>.{4})(?<z_acc>.{4})(?<rssi>.{2})$}


  def self.decode(packet_hex_string)
    return unless packet_hex_string && (match = PACKET_DATA_REGEX.match(packet_hex_string))

    tag_id = match[:tag_id]
    temperature = match[:temperature]
    x_acc = match[:x_acc]
    y_acc = match[:y_acc]
    z_acc = match[:z_acc]
    rssi = match[:rssi]

    {
      tag_id: tag_id,
      hex_temperature: temperature,
      hex_x_acc: x_acc,
      hex_y_acc: y_acc,
      hex_z_acc: z_acc,
      hex_rssi: rssi
    }
  end
end

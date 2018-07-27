lib_dir = ".."
require_relative "#{lib_dir}/measurement.rb"
require_relative "#{lib_dir}/packet_decoder.rb"

module Configurator
  class BLEScanner
    def self.run(seconds = 5)
      packets = []
      cmd = "#{__dir__}/../../../bin/tag_scanner.sh 2> /dev/null"

      # collect some packets
      IO.popen(cmd) do |io|
        end_time = Time.now.to_i + seconds
        while (line = io.gets)
          # check that there's data in packet_data and that it matches the Fujitsu Regex, since we'll get lots of irrelevant BLE packets
          begin
            packets << JSON.parse(line)
          rescue JSON::ParserError => ex
            # skip packets we can't decode
          end
          break if Time.now.to_i >= end_time
        end
      end

      # extract measurements from the collected packets
      measurements = packets.compact.map { |packet| Measurement.new(**PacketDecoder.decode(packet["packet_data"])) }
    end
  end
end

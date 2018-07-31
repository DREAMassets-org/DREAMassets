lib_dir = ".."
require_relative "#{lib_dir}/measurement.rb"
require_relative "#{lib_dir}/packet_decoder.rb"

module Configurator
  class BLEScanner
    def self.run(seconds = 5)
      input_payloads = []

      # collect some packets
      scan do |io|
        end_time = Time.now.to_i + seconds
        while (line = io.gets)
          # check that there's data in packet_data and that it matches the Fujitsu Regex, since we'll get lots of irrelevant BLE packets
          begin
            input_payloads << JSON.parse(line)
          rescue JSON::ParserError
            # skip packets we can't decode
          end
          break if Time.now.to_i >= end_time
        end
      end

      # extract measurements from the collected packets
      input_payloads.compact.map do |payload|
        decoded_packet = PacketDecoder.decode(payload["packet_data"]).merge(timestamp: payload["timestamp"])
        Measurement.new(**decoded_packet)
      end
    end

    def self.scan(&block)
      cmd = "#{__dir__}/../../../bin/tag_scanner.sh 2> /dev/null"
      IO.popen(cmd) do |io|
        block.call(io)
      end
    end
  end
end

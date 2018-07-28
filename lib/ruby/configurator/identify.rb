require "json"
require "io/console"
require "curses"

lib_dir = ".."
require_relative "#{lib_dir}/measurement.rb"
require_relative "#{lib_dir}/packet_decoder.rb"
require_relative "#{lib_dir}/string.rb"

module Configurator
  class Identify
    def self.run(options)
      Curses.init_screen
      Curses.start_color
      Curses.use_default_colors
      Curses.curs_set(0)

      number_of_tags = options.number_of_tags

      if number_of_tags.to_i <= 0
        puts "*** You must specify a number of tags to watch that is greatuer than 0"
        exit
      end

      loop do
        ctr = 0

        measurements = scan_for_tags(number_of_tags)
        #                .each_with_object({}) do |measurement, memo|
        #   (memo[measurement.tag_id] ||= []) << measurement
        # end.sort_by { |tag_id, measurements| derivative(&:z_acceleration).

        measurements.each_with_index do |measurement, index|
          Curses.setpos(index + 1, 0)
          Curses.addstr([index, measurement.tag_id, measurement.z_acceleration].join(","))
          Curses.refresh
        end
      end
    end

    class << self
      private

      def scan_for_tags(number_of_tags)
        BLEScanner.run do |io|
          ctr = 0
          while (line = io.gets)
            # check that there's data in packet_data and that it matches the Fujitsu Regex, since we'll get lots of irrelevant BLE packets
            begin
              packet = JSON.parse(line)
              measurement = Measurement.new(**PacketDecoder.decode(packet["packet_data"]))
              ctr = ctr + 1

              if ctr > number_of_tags
                puts "DONE"
                break
              end
            rescue JSON::ParserError => ex
              # skip packets we can't decode
            end
          end
        end
      end
    end
  end
end

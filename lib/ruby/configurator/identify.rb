require "json"
require "io/console"
require "curses"

lib_dir = ".."
require_relative "#{lib_dir}/measurement.rb"
require_relative "#{lib_dir}/packet_decoder.rb"
require_relative "#{lib_dir}/string.rb"

module Configurator
  class Measurements
    ROLLING_WINDOW_SIZE = 10
    def initialize
      @entries = []
    end

    def <<(entry)
      @entries << entry
    end

    def length
      @entries.length
    end

    def each
      @entries.each do |measurement|
        yield({ measurement: measurement, activity: activity })
      end
    end

    def activity(start_time)
      entries_vs_time = Array.new(@entries.last.timestamp.to_i - start_time, "-")
      @entries.each do |entry|
        ts = entry.timestamp.to_i - start_time
        entries_vs_time[ts] = "."
      end
      entries_vs_time.join

      # @entries_vs_time
      #   position = measurement.timestamp - start_time
      #   [

      # times = @entries.map{|x| x.timestamp.to_i - start_time if start_time && x.timestamp }
      # derivative(@entries, :z_acceleration).map{|d| d.abs > 0.5 ? "|" : "."}.join
    end

    private

    def derivative(_measurements, attribute)
      values = @entries.map { |m| m.send(attribute) }
      return [0] if values.length == 1
      values.each_cons(2).map { |x, y| y - x }
    end

    def sum_of_absolute_value(arr)
      arr.map(&:abs).reduce(&:+)
    end
  end

  class Identify
    def self.run(options)
      if !options.debug
        Curses.init_screen
        Curses.start_color
        Curses.use_default_colors
        Curses.curs_set(0)
      end

      number_of_tags = options.number_of_tags

      if number_of_tags.to_i <= 0
        puts "*** You must specify a number of tags to watch that is greatuer than 0"
        exit
      end

      grid = MeasurementGrid.new
      now = Time.now.to_i
      loop do
        ctr = 0

        scan_for_tags(number_of_tags).each do |measurement|
          puts "M", measurement.inspect
          (measurements_by_tag_id[measurement.tag_id] ||= Measurements.new) << measurement
        end

        measurements_by_tag_id.each_with_index do |(tag_id, measurements), index|
          if !options.debug
            Curses.setpos(index + 1, 0)
            Curses.addstr([index, tag_id, measurements.activity(now)].join(","))
            Curses.refresh
          else

            puts "ENTRY #{[index, tag_id, measurements.activity(now)].join("\t")}"
          end
        end
        puts "******************* \n\n"
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

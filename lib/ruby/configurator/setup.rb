# coding: utf-8

lib_dir = ".."
require_relative "#{lib_dir}/string.rb"
require_relative "#{lib_dir}/configurator/ble_scanner.rb"
require_relative "#{lib_dir}/configurator/configurator_data_file.rb"

module Configurator
  # A couple helper methods to render and format the output table
  class Table
    ROW_COLUMN_SIZE_MAP = [4, 20, 6, 6].freeze

    def self.format_header(row)
      [
        row[0].ljust(ROW_COLUMN_SIZE_MAP[0]),
        row[1].ljust(ROW_COLUMN_SIZE_MAP[1]),
        row[2].ljust(ROW_COLUMN_SIZE_MAP[2]),
        row[3].ljust(ROW_COLUMN_SIZE_MAP[3]),
        row[4]
      ].join(" ")
    end

    def self.format_row(row)
      [
        row[0].ljust(ROW_COLUMN_SIZE_MAP[0]),
        row[1].ljust(ROW_COLUMN_SIZE_MAP[1]),
        row[2].rjust(ROW_COLUMN_SIZE_MAP[2]),
        row[3].rjust(ROW_COLUMN_SIZE_MAP[3])
      ].join(" ")
    end
  end

  class Setup
    def self.run(options)
      scan_time = options.scan_time

      if scan_time.to_i <= 0
        puts "*** You must specify a scan_time greater than 0"
        exit
      end

      previous_rssis = {}
      now = Time.now.to_i

      previous_rssis, previously_recorded_at = load_previous_run

      print "Scanning for ~#{scan_time} seconds..."
      # here we add a little extra time to account for the fact that the scanner needs a few seconds to get started
      measurements = BLEScanner.run(scan_time + 3)
      puts "done"

      average_rssis = average_rssi_by_tag_id(measurements)
      age = now - previously_recorded_at.to_i

      puts "----"
      puts "The last time you ran Configurator Setup was #{age} seconds ago"
      puts Table.format_header(["(#)", "Tag ID", "  RSSI", " Δ RSSI"])
      average_rssis.sort_by { |_tag_id, rssi| -rssi }.each_with_index do |(tag_id, rssi), index|
        previous_rssi = previous_rssis[tag_id]

        delta_rssi = previous_rssi ? (previous_rssi - rssi) : "-"
        puts Table.format_row([format("(%d)", index + 1), tag_id.as_byte_pairs, rssi.to_s, delta_rssi.to_s])
      end
      save_current_run(average_rssis)
    end

    class << self
      private

      # Save the current set of rolled up data in a json file so we can
      # report the changes between the current run and the last time this was run
      def save_current_run(current_run_data)
        ConfiguratorDataFile.write(current_run_data)
      end

      def load_previous_run
        ConfiguratorDataFile.read
      end

      # Return average RSSI for each tag we see in the measurements
      def average_rssi_by_tag_id(measurements)
        measurements.each_with_object({}) do |measurement, memo|
          # Build RSSI array for each measurement on this tag
          (memo[measurement.tag_id] ||= []) << measurement.rssi
        end.each_with_object({}) do |(tag_id, rssis), memo|
          # compute RSSI average
          memo[tag_id] = average(rssis)
        end
      end

      def average(numbers)
        numbers.reduce(&:+) / numbers.length
      end
    end
  end
end

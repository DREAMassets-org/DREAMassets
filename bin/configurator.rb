#!/usr/bin/env ruby
# coding: utf-8

# Configurator
#
# This script should help us find and identify tags that are near the device it's run on.
# It is expected to run on a Raspberry Pi and will listen for BLE devices in the vicinity and report
# what it finds

require "ostruct"
require "optparse"
require "json"
require "fileutils"

# require local ruby helpers and classes
lib_dir = "../lib/ruby"
require_relative "#{lib_dir}/measurement.rb"
require_relative "#{lib_dir}/packet_decoder.rb"
require_relative "#{lib_dir}/string.rb"
# define (and package in a class) the configurator functions
class Configurator
  CONFIGURATOR_DATA_DIR = ".configurator".freeze
  CONFIGURATOR_DATA_FILE = File.join(CONFIGURATOR_DATA_DIR, "configurator.json")

  def self.setup(options)
    previous_rssis = {}
    now = Time.now.to_i

    FileUtils.mkdir_p(CONFIGURATOR_DATA_DIR)

    if File.exist?(CONFIGURATOR_DATA_FILE)
      previous_rssis = JSON.parse(File.open(CONFIGURATOR_DATA_FILE).read)
      previously_recorded_at = File.ctime(CONFIGURATOR_DATA_FILE).to_i
    end

    scan_time = options.scan_time

    print "Scanning for ~#{scan_time} seconds..."
    # here we add a little extra time to account for the fact that the scanner needs a few seconds to get started
    measurements = scan_ble(scan_time + 3)
    puts "done"

    average_rssis = average_rssi_by_tag_id(measurements)
    age = now - previously_recorded_at.to_i

    puts ConfiguratorTable.format_header(["(#)", "Tag ID", "RSSI", "Δ RSSI", "Previously Run #{age} secs ago"])
    average_rssis.sort_by { |_tag_id, rssi| -rssi }.each_with_index do |(tag_id, rssi), index|
      previous_rssi = previous_rssis[tag_id]

      delta_rssi = previous_rssi ? (previous_rssi - rssi) : "-"
      puts ConfiguratorTable.format_row([format("(%d)", index + 1), tag_id.as_byte_pairs, rssi.to_s, delta_rssi.to_s])
    end
    save_current_run(average_rssis, CONFIGURATOR_DATA_FILE)
  end

  class ConfiguratorTable
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

  class << self
    private

    # Save the current set of rolled up data in a json file so we can
    # report the changes between the current run and the last time this was run
    def save_current_run(aggregated_measurements, filename)
      fp = File.open(filename, "w")
      fp.write(JSON.generate(aggregated_measurements))
      fp.close
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

    def scan_ble(num_seconds)
      packets = []
      cmd = "#{__dir__}/tag_scanner.sh 2> /dev/null"

      # collect some packets
      IO.popen(cmd) do |io|
        end_time = Time.now.to_i + num_seconds
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

    def average(numbers)
      numbers.reduce(&:+) / numbers.length
    end
  end
end

banner = """

 ______   ______    _______  _______  __   __
|      | |    _ |  |       ||   _   ||  |_|  |
|  _    ||   | ||  |    ___||  |_|  ||       |
| | |   ||   |_||_ |   |___ |       ||       |
| |_|   ||    __  ||    ___||       ||       |
|       ||   |  | ||   |___ |   _   || ||_|| |
|______| |___|  |_||_______||__| |__||_|   |_|
 _______  _______  _______  _______  _______  _______
|   _   ||       ||       ||       ||       ||       |
|  |_|  ||  _____||  _____||    ___||_     _||  _____|
|       || |_____ | |_____ |   |___   |   |  | |_____
|       ||_____  ||_____  ||    ___|  |   |  |_____  |
|   _   | _____| | _____| ||   |___   |   |   _____| |
|__| |__||_______||_______||_______|  |___|  |_______|
 _______  _______  __    _  _______  ___   _______  __   __  ______    _______  _______  _______  ______
|       ||       ||  |  | ||       ||   | |       ||  | |  ||    _ |  |   _   ||       ||       ||    _ |
|       ||   _   ||   |_| ||    ___||   | |    ___||  | |  ||   | ||  |  |_|  ||_     _||   _   ||   | ||
|       ||  | |  ||       ||   |___ |   | |   | __ |  |_|  ||   |_||_ |       |  |   |  |  | |  ||   |_||_
|      _||  |_|  ||  _    ||    ___||   | |   ||  ||       ||    __  ||       |  |   |  |  |_|  ||    __  |
|     |_ |       || | |   ||   |    |   | |   |_| ||       ||   |  | ||   _   |  |   |  |       ||   |  | |
|_______||_______||_|  |__||___|    |___| |_______||_______||___|  |_||__| |__|  |___|  |_______||___|  |_|

"""

options_banner = """
This configurator should be used to identify BLE Fujitu tags near the hub running it.
It is expected to be running on a RaspberryPi.

Usage: #{$PROGRAM_NAME} <command> [options]

<command> should be one of \"setup\" or \"identify\"

Options:
"""

# Parse command line arguments
options = OpenStruct.new
parser = OptionParser.new do |opts|
  opts.banner = options_banner

  opts.on("-s", "--scan-time [SECONDS]", "How long to run the scan (in seconds)") do |val|
    options.scan_time = val.to_i
  end

  opts.on("-h", "--help", "Displays Help") do
    puts banner
    puts opts
    exit
  end
end

parser.parse!

command = ARGV.shift

unless command
  puts "***"
  puts "*** You need to specify a command"
  puts "***"
  puts parser
  exit
end

# run the desired command (based on command line arguments)
Configurator.send(command, options)

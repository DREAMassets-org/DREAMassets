#!/usr/bin/env ruby
# coding: utf-8

# Configurator
#
# This script should help us find and identify tags that are near the device it's run on.
# It is expected to run on a Raspberry Pi and will listen for BLE devices in the vicinity and report
# what it finds

# Use the bundler library to get external libraries from the internet
require "bundler"
require "ostruct"
require "optparse"
require "json"
require "fileutils"
require "curses"

# require local ruby helpers and classes
lib_dir = "../lib/ruby"
require_relative "#{lib_dir}/configurator/setup.rb"
require_relative "#{lib_dir}/configurator/identify.rb"
require_relative "#{lib_dir}/configurator/banner.rb"

# define (and package in a class) the configurator functions
module Configurator
  # This is the main routine for the configurator when you are running in identification mode
  def self.identify(options)
    Identify.new(options).run
  end

  # This is the main routine for the configurator when you are running in setup mode
  def self.setup(options)
    Setup.run(options)
  end
end

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

  opts.on("-n", "--number-of-tags [NUMBER]", "Top N tags to consider during identification (for identify mode only)") do |val|
    options.number_of_tags = val.to_i
  end

  opts.on("-s", "--scan-time [SECONDS]", "How long to run the scan (in seconds) (for setup mode only)") do |val|
    options.scan_time = val.to_i
  end

  opts.on("-D", "--debug", "Debug mode... just scroll the output") do
    options.debug = true
  end

  opts.on("-h", "--help", "Displays Help") do
    puts Banner.new.to_s
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

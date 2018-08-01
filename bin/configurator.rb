#!/usr/bin/env ruby
# coding: utf-8

# ***Configurator***
# This script finds and identifies Tags that are near the Hub (Raspberry Pi) running this script.
#
# The Configurator operates in two modes: setup and identify.
#
# In setup mode, the Configurator lists all of the Tags it finds, 
# which are a combination of the Tags you're interested in (probably on your desk) and other nearby Tags that are noise
# The role of setup mode is for you to isolate the Tags you care about from any other Tags
# For instance, you want to identify 3 Tags and the Configurator finds 9 Tags nearby 
# The output from setup mode is a list of tags in descending order by signal strength (strongest signal is #1)
# Signal strength (RSSI) tends to vary a lot, so your 3 tags might be in the top 5 that Configurator identifies
# The value of Setup mode is that you can isolate and ignore Tags creating noise  
# 
# In identify mode, the Configurator tells you the Tag ID of the Tags that you flip
# For identify mode, you tell Configurator how many Tags from the setup list you want to examine
# In our example, that would be the top 5 Tags
# Configurator expects you to lie the Tags flat to establish a baseline
# Then Configurator prompts you to flip one Tag at a time
# When you're done, Configurator outputs a list of Tags in the order your flipped them. 


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
  # This is the main routine for the configurator when you are running in `identification` mode
  def self.identify(options)
    Identify.new(options).run
  end

  # This is the main routine for the configurator when you are running in `setup` mode
  def self.setup(options)
    Setup.run(options)
  end
end

options_banner = """
This Configurator is designed to identify Fujitu BLE Tags near the Hub running Configurator.

You need to specify whether to run Configurator in \"setup\" or \"identify\" mode 
where <command> is either \"setup\" or \"identify\" followed by an option 

Usage: #{$PROGRAM_NAME} <command> [options]

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

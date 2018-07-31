require "json"
require "io/console"
require "curses"
require "byebug"

lib_dir = ".."
require_relative "#{lib_dir}/measurement.rb"
require_relative "#{lib_dir}/packet_decoder.rb"
require_relative "#{lib_dir}/string.rb"
require_relative "#{lib_dir}/configurator/measurement_grid.rb"
require_relative "#{lib_dir}/configurator/configurator_data_file.rb"
require_relative "#{lib_dir}/configurator/banner.rb"

module Configurator
  class Identify
    MAX_SECONDS_BETWEEN_SETUP_AND_IDENTIFICATION = 20 * 60 # 20 minutes
    WINDOW_SIZE = 80

    def initialize(options)
      @options = options
      @tags_to_watch = []
    end

    def run
      if @options.number_of_tags.to_i <= 0
        puts "*** You must specify a number of tags to watch that is greatuer than 0"
        exit
      end

      verify_configurator_setup
      setup_tags_to_watch
      setup_exit_code_traps
      verify_enough_reporting_tags

      initialize_grid
      initialize_window

      loop do
        scan_for_tags.each do |measurement|
          @grid << measurement if @tags_to_watch.include?(measurement.tag_id)
        end

        @grid.tags.each_with_index do |tag, index|
          tag_activity = @grid.flipped(tag).join("")
          trimmed_deriv = tag_activity[-WINDOW_SIZE..-1] || tag_activity
          render_row([tag, trimmed_deriv].join("\t"), index + 1)
        end

        render_info_rows(@tags_to_watch.count + 2)

        unless @options.debug
          Curses.refresh
        end
      end
    end

    private

    def initialize_window
      return if @options.debug
      Curses.init_screen
      Curses.start_color
      Curses.use_default_colors
      Curses.curs_set(0)
    end

    def initialize_grid
      @grid = MeasurementGrid.new(:z_acceleration, window_size: 80, expected_tags: @tags_to_watch)
    end

    def render_intro
      row = 1
      Banner.new.to_s.split(/\n/).each do |line|
        row = render_row(line, row + 1)
      end
    end

    def render_info_rows(starts_at = 0)
      last_row = starts_at

      last_row = if @grid.stabilizing?
        render_row("Stabilizing...", last_row)
      else
        render_row("All tags have reported in", last_row)
      end

      last_row = render_row("Please flip one tag at a time.  Once you see a `|`, you can flip another one.", last_row + 2)
      last_row = render_row("You will probably wait a few seconds between each flip.", last_row + 1)
      render_row("When you're done, hit Ctrl+C to quit and we'll show you the tag ids in order of their last recorded flips.", last_row + 1)
    end

    def verify_enough_reporting_tags
      if @tags_to_watch.length < @options.number_of_tags
        puts "We were unable to find #{@options.number_of_tags} in the neighborhood."
        puts "At last count, we saw #{@tags_to_watch.length}"
        puts "Please try again with a smaller number"
        exit
      end
    end

    def setup_tags_to_watch
      last_run_tags, _last_run_ts = ConfiguratorDataFile.read
      @tags_to_watch = last_run_tags.sort_by { |_tag, rssi| -rssi }.map(&:first).first(@options.number_of_tags)
    end

    def setup_exit_code_traps
      # Because we're running a windowed app, trap interupt events
      for i in %w[HUP INT QUIT TERM]
        if trap(i, "SIG_IGN") != 0 # 0 for SIG_IGN
          trap(i) do |sig|
            Curses.close_screen
            puts "Thanks for playing."
            puts
            puts "Here are the tags you flipped."
            @grid.latest_active_tags_in_order.each_with_index do |tag, index|
              puts "#{format("(%d)", index + 1)} #{tag.as_byte_pairs}"
            end
            exit sig
          end
        end
      end
    end

    def render_row(s, row)
      if @options.debug
        puts s
      else
        Curses.setpos(row, 0)
        Curses.addstr(s)
      end
      row
    end

    def verify_configurator_setup
      seconds_since_last_run = Time.now.to_i - ConfiguratorDataFile.latest_run_time.to_i
      if seconds_since_last_run > MAX_SECONDS_BETWEEN_SETUP_AND_IDENTIFICATION
        puts "****  You haven't run setup in a while so I'll run it for you ****"
        @options.scan_time = 20 unless @options.scan_time
        Configurator::Setup.run(@options)
      end
    end

    def scan_for_tags
      BLEScanner.run(5) do |io|
        while (line = io.gets)
          begin
            packet = JSON.parse(line)
            Measurement.new(**PacketDecoder.decode(packet["packet_data"]))
          rescue JSON::ParserError
            # skip packets we can't decode
          end
        end
      end
    end
  end
end

require "fileutils"

class ConfiguratorDataFile
  CONFIGURATOR_DATA_DIR = ".configurator".freeze
  CONFIGURATOR_DATA_FILE = File.join(CONFIGURATOR_DATA_DIR, "configurator.json")

  def self.write(data)
    fp = File.open(CONFIGURATOR_DATA_FILE, "w")
    fp.write(JSON.generate(data))
    fp.close
  end

  def self.latest_run_time
    return Time.at(0) unless File.exist?(CONFIGURATOR_DATA_FILE)
    File.ctime(CONFIGURATOR_DATA_FILE)
  end

  def self.read
    return [{}, nil] unless File.exist?(CONFIGURATOR_DATA_FILE)
    begin
      [
        JSON.parse(File.open(CONFIGURATOR_DATA_FILE).read),
        latest_run_time.to_i
      ]
    rescue JSON::ParserError
      [{}, nil]
    end
  end

  class << self
    private

    def ensure_configurator_directory
      FileUtils.mkdir_p(CONFIGURATOR_DATA_DIR)
    end
  end
end

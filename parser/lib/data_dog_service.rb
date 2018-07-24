# DataDog is our cloud storage and visualisation platform
class DataDogService

  HOSTNAME = `hostname`

  DATA_BUNDLE_SIZE = 100

  # We need to give DataDog our API key so they know it's us sending data
  # Also include how many measurements to collect before sending
  def initialize(api_key, bundle_size=DATA_BUNDLE_SIZE)
    @api_key = api_key
    @bundle_size = bundle_size
    @measurements = []
  end

  def add_measurement(packet)
    @measurements << packet
    if @measurements.length >= @bundle_size
      send_and_reset_bundle
    end
  end

  def send_and_reset_bundle
    %i( x_acceleration y_acceleration z_acceleration temperature rssi ).each do |metric|
      data_by_tag_id = @measurements.each_with_object({}) do |measurement, obj|
        obj[measurement.tag_id] ||= []
        obj[measurement.tag_id] << [ measurement.timestamp, measurement.send(metric) ]
      end
      data_by_tag_id.each do |tag_id, datapoints|
        client.emit_points("fujitsu.#{metric}", datapoints, host: HOSTNAME, device: tag_id)
      end
    end
    @measurements = []
  end

  # client is the destination where we send our data. Client is a wrapper for a URL where we send our data
  private
  def client
    @client ||= Dogapi::Client.new(@api_key)
  end
end

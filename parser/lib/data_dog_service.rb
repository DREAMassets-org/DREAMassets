# DataDog is our cloud storage and visualisation platform
class DataDogService

  HOSTNAME = `hostname`

  DATA_BUNDLE_SIZE = 100

  # We need to give DataDog our API key so they know it's us sending data
  # Also include how many events to collect before sending
  def initialize(api_key, bundle_size=DATA_BUNDLE_SIZE)
    @api_key = api_key
    @bundle_size = bundle_size
    @events = []
  end

  def add_event(packet)
    @events << packet
    if @events.length >= @bundle_size
      send_and_reset_events
    end
  end

  def send_and_reset_events
    %i( x_acceleration y_acceleration z_acceleration temperature rssi ).each do |metric|
      data_by_device_id = @events.each_with_object({}) do |event, obj|
        obj[event.device_id] ||= []
        obj[event.device_id] << [ event.timestamp, event.send(metric) ]
      end
      data_by_device_id.each do |device_id, datapoints|
        client.emit_points("fujitsu.#{metric}", datapoints, host: HOSTNAME, device: device_id)
        #puts "sent to datadog #{device_id} : #{datapoints}"
      end
    end
    @events = []
  end

  # client is the destination where we send our data. Client is a wrapper for a URL where we send our data
  private
  def client
    @client ||= Dogapi::Client.new(@api_key)
  end
end

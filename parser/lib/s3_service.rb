# Ruby wrapper for our connection to S3 which should
# bundle a group of events into a csv (or json) file and send it to a bucket

require 'aws-sdk-s3'

class S3Service

  HOSTNAME = `hostname`

  DATA_BUNDLE_SIZE = 1000

  # AWS client looks in our environment for keys, so you need to set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY and AWS_REGION
  # Also include the bucket to write to, the bundle size (how many events to collect in each file),
  # and the format.
  # By default we'll go with 100 events per bundle and CSV format
  def initialize(bucket, bundle_size: DATA_BUNDLE_SIZE, format: :json)

    has_aws_keys = ENV.fetch('AWS_ACCESS_KEY_ID') && ENV.fetch('AWS_SECRET_ACCESS_KEY') && ENV.fetch('AWS_REGION')
    if !has_aws_keys
      raise ArgumentError.new("You must set (in your environment) AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_REGION to continue with S3 uploads")
    end

    @bundle_size = bundle_size
    @bucket = bucket
    @format = format
    @events = []
  end

  def add_event(packet)
    @events << packet
    if @events.length >= @bundle_size
      send_and_reset_events
    end
  end

  def send_and_reset_events
    return unless @events.length > 0

    filename = sprintf("%s-%f.%s", HOSTNAME.chomp, Time.now.to_f, @format)
    file = bucket.object(filename)
    puts "FORMATTED", formatted_events
    file.put(body: formatted_events)
    @events = []
  end


  # client is the destination where we send our data. Client is a wrapper for a URL where we send our data
  private

  def formatted_events
    if @format.to_s == "json"
      return events_as_json
    end
  end

  def events_as_json
    JSON.generate(@events.map(&:as_json))
  end

  def bucket
    s3 ||= Aws::S3::Resource.new.bucket(@bucket)
  end

end

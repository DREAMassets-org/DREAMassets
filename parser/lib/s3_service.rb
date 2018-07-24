# Ruby wrapper for our connection to S3 which should
# bundle a group of measurements into a csv (or json) file and send it to a bucket

require 'aws-sdk-s3'

class S3Service

  HOSTNAME = `hostname`

  DATA_BUNDLE_SIZE = 1000

  # AWS client looks in our environment for keys, so you need to set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY and AWS_REGION
  # Also include the bucket to write to, the bundle size (how many measurements to collect in each file),
  # and the format.
  # By default we'll go with 100 measurements per bundle and CSV format
  def initialize(bucket, directory: nil, bundle_size: DATA_BUNDLE_SIZE, format: :csv)

    has_aws_keys = ENV.fetch('AWS_ACCESS_KEY_ID') && ENV.fetch('AWS_SECRET_ACCESS_KEY') && ENV.fetch('AWS_REGION')
    if !has_aws_keys
      raise ArgumentError.new("You must set (in your environment) AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_REGION to continue with S3 uploads")
    end

    @bundle_size = bundle_size
    @bucket = bucket
    @directory = directory
    @format = format
    @measurements = []
  end

  def add_measurement(measurement)
    @measurements << measurement
    if @measurements.length >= @bundle_size
      send_and_reset_bundle
    end
  end

  def send_and_reset_bundle
    return unless @measurements.length > 0

    filename = sprintf("%s-%f.%s", HOSTNAME.chomp, Time.now.to_f, @format)
    file = bucket.object([ @directory, filename ].compact.join("/"))
    file.put(body: formatted_measurements)
    @measurements = []
  end


  # client is the destination where we send our data. Client is a wrapper for a URL where we send our data
  private

  def formatted_measurements
    (@format.to_s == "json") ? measurements_as_json : measurements_as_csv
  end

  def measurements_as_json
    JSON.generate(@measurements.map(&:as_json))
  end

  def measurements_as_csv
    @measurements.map { |measurement| measurement.csv_row }.join("\n")
  end

  def bucket
    s3 ||= Aws::S3::Resource.new.bucket(@bucket)
  end

end

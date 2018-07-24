# Ruby wrapper for our connection to S3 which should
# bundle a group of measurements into a csv (or json) file and send it to a bucket

require 'aws-sdk-s3'

class S3Service

  # AWS client looks in our environment for keys, so you need to set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY and AWS_REGION
  # Also include the bucket to write to, the bundle size (how many measurements to collect in each file),
  # and the format.
  # By default we'll go with 100 measurements per bundle and CSV format
  def initialize(hub_id, bucket_name, directory: nil)

    has_aws_keys = ENV.fetch('AWS_ACCESS_KEY_ID') && ENV.fetch('AWS_SECRET_ACCESS_KEY') && ENV.fetch('AWS_REGION')
    if !has_aws_keys
      raise ArgumentError.new("You must set (in your environment) AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_REGION to continue with S3 uploads")
    end
    @hub_id = hub_id
    @bucket_name = bucket_name
    @directory = directory
  end

  def send(measurements)
    return unless measurements.length > 0

    filename = sprintf("%s-%f.csv", @hub_id, Time.now.to_f)
    file = bucket.object([ @directory, filename ].compact.join("/"))
    file.put(body: formatted_measurements(measurements))
  end


  # client is the destination where we send our data. Client is a wrapper for a URL where we send our data
  private

  def formatted_measurements(measurements)
    # return the data as a String that is in CSV format
    measurements.map { |measurement| measurement.csv_row }.join("\n")
  end

  def bucket
    s3 ||= Aws::S3::Resource.new.bucket(@bucket_name)
  end

end

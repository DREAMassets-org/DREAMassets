# Ruby wrapper for our connection to S3
# provides one primary method `#send` which takes an array of measurments and sends them to S3 as a csv file

require 'aws-sdk-s3'

class S3Service

  # AWS client looks in our environment for keys, so you need to set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY and AWS_REGION
  # We also want the hub_id (hostname of the hub), the bucket and optional directory in which to write the files
  def initialize(hub_id, bucket_name, directory: nil)

    has_aws_keys = ENV.fetch('AWS_ACCESS_KEY_ID') && ENV.fetch('AWS_SECRET_ACCESS_KEY') && ENV.fetch('AWS_REGION')
    if !has_aws_keys
      raise ArgumentError.new("You must set (in your environment) AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_REGION to continue with S3 uploads")
    end
    @hub_id = hub_id
    @bucket_name = bucket_name
    @directory = directory
  end

  # Given an array of Measurement objects, serialize them as CSV and send them to S3 in a file called "<hub id>-<timestamp>.csv"
  def upload(measurements)
    return unless measurements.length > 0

    file = bucket.object(generate_filename)
    file.put(body: format_measurements(measurements))
  end


  # client is the destination where we send our data. Client is a wrapper for a URL where we send our data
  private

  def generate_filename
    filename = sprintf("%s-%f.csv", @hub_id, Time.now.to_f)
    [ @directory, filename ].compact.join("/")
  end

  def format_measurements(measurements)
    # return the data as a String that is in CSV format
    measurements.map { |measurement| measurement.csv_row }.join("\n")
  end

  def bucket
    s3 ||= Aws::S3::Resource.new.bucket(@bucket_name)
  end

end

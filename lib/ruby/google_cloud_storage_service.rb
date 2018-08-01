# This library contains methods and functions for packet_parser.rb (and maybe other rb's)
#
# Ruby wrapper for our connection to GoogleCloudStorage
# provides one primary method `#send` which takes an array of measurments and sends them to GoogleCloudStorage as a csv file

require "google/cloud/storage"

class GoogleCloudStorageService
  # We need the hub_id (hostname of the Raspberry Pi hub), the bucket in Google Storage and (optional) directory where we'll write the files
  # the `directory` is optional; the other variables are manditory
  def initialize(project_id, credentials_file, hub_id, bucket_name, directory: nil)
    @project_id = project_id
    @project_credentials_json_file = credentials_file
    @hub_id = hub_id
    @bucket_name = bucket_name
    @base_directory = directory
  end

  # Given an array of Measurement objects, serialize them as CSVs and send them to GoogleCloudStorage in a file called "<hub id>-<timestamp>.csv"
  def upload(measurements)
    return unless !measurements.empty?

    bucket.create_file(StringIO.new(format_measurements(measurements)), generate_filename)
  end

  # client is the destination in Google Cloud where we send our data. Client is a wrapper for a URL where we send our data
  private

  def generate_filename
    filename = sprintf("%s-%f.csv", @hub_id, Time.now.to_f)
    [directory, filename].compact.join("/")
  end

  def format_measurements(measurements)
    # return the data as a String that is in CSV format
    measurements.map(&:csv_row).join("\n")
  end

  def directory
    now = Time.now
    File.join(@base_directory, now.strftime("%Y/%m/%W"))
  end

  def bucket
    storage = Google::Cloud::Storage.new(project_id: @project_id, credentials: @project_credentials_json_file)
    bucket = storage.bucket(@bucket_name)
    if !bucket
      bucket = storage.create_bucket(@bucket_name)
    end
    bucket
  end
end

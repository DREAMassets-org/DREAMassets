# Ruby wrapper for our connection to GoogleCloudStorage
# provides one primary method `#send` which takes an array of measurments and sends them to GoogleCloudStorage as a csv file

require 'google/cloud/storage'

class GoogleCloudStorageService

  # We need the hub_id (hostname of the hub), the bucket and optional directory in which to write the files
  def initialize(project_id, credentials_file, hub_id, bucket_name, directory: nil)
    @project_id = project_id
    @project_credentials_json_file = credentials_file
    @hub_id = hub_id
    @bucket_name = bucket_name
    @directory = directory
  end

  # Given an array of Measurement objects, serialize them as CSV and send them to GoogleCloudStorage in a file called "<hub id>-<timestamp>.csv"
  def upload(measurements)
    return unless measurements.length > 0

    bucket.create_file( StringIO.new(format_measurements(measurements)), generate_filename )
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
    storage = Google::Cloud::Storage.new( project_id: @project_id, credentials: @project_credentials_json_file)
    bucket = storage.bucket(@bucket_name)
    if !bucket
      bucket = storage.create_bucket(@bucket_name)
    end
    bucket
  end

end

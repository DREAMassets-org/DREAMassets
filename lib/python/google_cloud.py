from google.cloud import storage
import time
import io
import json

class GoogleCloudStorage:
  def __init__(self, project_id, credentials_file, hub_id, bucket_name, directory, logger):
    self.project_id = project_id
    self.credentials_file = credentials_file
    self.hub_id = hub_id
    self.bucket_name = bucket_name
    self.base_directory = directory or ''
    self.client = None
    self.suffix = None
    self.content_type = None
    self.mime_type = None
    self.logger = logger

  def upload(self, measurements):
    self.logger and self.logger.debug("Uploading %d measurements", len(measurements))
    if len(measurements) <= 0:
      return
    blob = storage.blob.Blob(self._generate_filename(), self._bucket())
    blob.upload_from_string(self._format_measurements(measurements), self.mime_type)

  def _client(self):
    if not self.client:
      self.client = storage.client.Client.from_service_account_json(self.credentials_file)
    return self.client

  def _generate_filename(self):
    filename = "%s-%f" % ( self.hub_id, time.time() )
    return "/".join([self.base_directory, time.strftime("%Y/%m/%d"), filename])

  def _bucket(self):
    return self._client().get_bucket(self.bucket_name)

class GoogleCloudCSVStorage(GoogleCloudStorage):

  HEADERS = ['hub_id', 'tag_id','temperature', 'x_acc', 'y_acc', 'z_acc',  'rssi', 'timestamp']

  def __init__(self, project_id, credentials_file, hub_id, bucket_name, directory, logger):
    GoogleCloudStorage.__init__(self,project_id, credentials_file, hub_id, bucket_name, directory, logger)
    self.suffix = "csv"
    self.mime_type = "text/csv"
    self.content_type = "text/csv"

  def _format_measurements(self, measurements):
    return "\n".join(map(self._measurement_row, measurements))

  def _measurement_row(self, measurement):
    return ",".join([
      measurement['hub_id'],
      measurement['tag_id'],
      "%2.2f" % measurement['temperature'],
      "%2.3f" % measurement['x_acc'],
      "%2.3f" % measurement['y_acc'],
      "%2.3f" % measurement['z_acc'],
      "%d" % measurement['rssi'],
      "%d" % measurement['timestamp']
    ])

  def _generate_filename(self):
    return GoogleCloudStorage._generate_filename(self) + ".csv"

class GoogleCsvUploader():
  def __init__(self, project_id, credentials_file, hub_id, bucket_name, directory, logger):
    self.project_id = project_id
    self.credentials_file = credentials_file
    self.hub_id = hub_id
    self.bucket_name = bucket_name
    self.base_directory = directory or ''
    self.logger = logger

  def package_and_upload(self, measurements):
    self.logger and self.logger.info("Writing %d measurements to %s" % ( len(measurements), self.bucket_name ))
    gcs = GoogleCloudCSVStorage(self.project_id, self.credentials_file, self.hub_id, self.bucket_name, self.base_directory, self.logger)
    gcs.upload(measurements)

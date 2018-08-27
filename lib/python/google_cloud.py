from google.cloud import storage, bigquery
import google.api_core.exceptions as exceptions
import time
import six

# We originally had the Hub interact with BigQuery 
# but we've disabled this by default. We don't really use this code. 
class GoogleBigQuery:
  def __init__(self, project_id, credentials_file,  dataset_name, table_name, logger=None):
    self.project_id = project_id
    self.credentials_file = credentials_file
    self.dataset_name = dataset_name
    self.table_name = table_name
    self.logger = logger
    self.client = bigquery.Client.from_service_account_json(self.credentials_file)
    self.bq_table = self.client.dataset(self.dataset_name).table(self.table_name)

  def update(self, csv_url):
    self.logger and self.logger.debug("Building BigQuery append job")
    job_config = bigquery.LoadJobConfig()
    job_config.write_disposition = bigquery.WriteDisposition.WRITE_APPEND
    job_config.skip_leading_rows = 0
    # The source format defaults to CSV, so the line below is optional.
    job_config.source_format = bigquery.SourceFormat.CSV
    self.logger and self.logger.info("Updating BiqQuery with the new data")
    job_id = "<unknown>"
    try:
      load_job = self.client.load_table_from_uri(
        csv_url,
        self.bq_table,
        job_config=job_config)  # API request
      job_id = load_job.job_id
      self.logger and self.logger.debug("Waiting on BigQuery job id %s type: %s" % (job_id, load_job.job_type))

      load_job.result()  # Waits for table load to complete.
      self.logger and self.logger.debug("[job: %s] BigQuery job is %s" % (job_id, load_job.state))

      new_table_size = self.client.get_table(self.bq_table).num_rows
      self.logger and self.logger.debug("[job: %s] Done running BigQuery table update - now table has %d rows" % (job_id, new_table_size))
    except (exceptions.BadRequest, exceptions.NotFound) as bad_request:
      self.logger and self.logger.error("[job: %s] failed %s" % (job_id, bad_request))


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

  def upload(self, bundle):
    if len(bundle) <= 0:
      return
    self.logger and self.logger.debug("Uploading a bundle of %d measurements", len(bundle))
    filename = self._generate_filename()
    blob = storage.blob.Blob(filename, self._bucket())
    blob.upload_from_string(self._format_measurements(bundle), self.mime_type)

    google_url = "gs://%s/%s" % (self.bucket_name, filename)
    return google_url

  def _client(self):
    if not self.client:
      self.client = storage.client.Client.from_service_account_json(self.credentials_file)
    return self.client

  def _generate_filename(self):
    filename = "%s-%f" % (self.hub_id, time.time())
    # we declare the file name here. it only uses Hub ID, but could add more info.
    return "/".join([self.base_directory, time.strftime("%Y/%m/%d"), filename])

  def _bucket(self):
    return self._client().get_bucket(self.bucket_name)

# why do we have this class? we output in this format with the -v option, but never to Google Cloud (i thought)
class GoogleCloudCSVStorage(GoogleCloudStorage):

  HEADERS = ['hub_id', 'tag_id', 'temperature', 'x_acc', 'y_acc', 'z_acc',  'rssi', 'timestamp']

  def __init__(self, project_id, credentials_file, hub_id, bucket_name, directory, logger=None):
    GoogleCloudStorage.__init__(self, project_id, credentials_file, hub_id, bucket_name, directory, logger)
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

# we don't (?) use this class because it's for BiqQuery which we're not using
class GoogleCsvUploader():
  def __init__(self, project_id, credentials_file, hub_id, bucket_name, directory, dataset_name, table_name, **kwargs):
    self.project_id = project_id
    self.credentials_file = credentials_file
    self.hub_id = hub_id
    self.bucket_name = bucket_name
    self.base_directory = directory or ''
    self.dataset_name = dataset_name
    self.table_name = table_name
    self.auto_update_big_query = kwargs.get('big_query_update', False)
    self.logger = kwargs.get('logger', None)

  def package_and_upload(self, measurements):
    self.logger and self.logger.info("Uploading %d measurements to the %s bucket" % (len(measurements), self.bucket_name))
    gcs = GoogleCloudCSVStorage(self.project_id, self.credentials_file, self.hub_id, self.bucket_name, self.base_directory, self.logger)
    url = gcs.upload(measurements)
    self.logger and self.logger.debug("Uploaded to %s" % url)

    if self.auto_update_big_query:
      gbq = GoogleBigQuery(self.project_id, self.credentials_file, self.dataset_name, self.table_name, self.logger)
      gbq.update(url)
      self.logger and self.logger.debug("Updated BigQuery:%s:%s" % (self.dataset_name, self.table_name))
    return url

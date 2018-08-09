#!/usr/bin/env python
import time
import sys
from google.cloud import bigquery
from urllib.parse import urlparse, parse_qs

def build_query(env, period, target):
    threshold = { 'day': 1000, 'hour': 100 }[period]
    return """
      SELECT *,(
        CASE when measurement_count > {threshold}
        then 'yes'
        else 'no'
        END
        ) AS {target}_is_reporting
      FROM (
        SELECT
          {target}_id,
          count(*) as measurement_count,
          datetime_trunc(DATETIME(PARSE_TIMESTAMP("%s", cast(timestamp as string)), "America/Los_Angeles"), {period}) as ts
        FROM
          {dataset}.{table}
        GROUP BY {target}_id, ts
        ORDER BY ts desc, {target}_id
      )
    """.format(target=target, period=period, threshold=threshold, dataset=env['bq_dataset'], table=env['bq_table'])

def tag_events_per_hour(env):
    filename = 'events/measurements_per_tag_per_hour.%s.csv' % time.strftime("%Y%m%d")
    query = build_query(env, "hour", "tag")
    run_query_and_dump_to_csv(env, query, filename)

def tag_events_per_day(env):
    query = build_query(env, "day", "tag")
    filename = 'events/measurements_per_tag_per_day.%s.csv' % time.strftime("%Y%m%d")
    run_query_and_dump_to_csv(env, query, filename)

def hub_events_per_hour(env):
    filename = 'events/measurements_per_hub_per_hour.%s.csv' % time.strftime("%Y%m%d")
    query = build_query(env, "hour", "hub")
    run_query_and_dump_to_csv(env, query, filename)

def hub_events_per_day(env):
    query = build_query(env, "day", "hub")
    filename = 'events/measurements_per_hub_per_day.%s.csv' % time.strftime("%Y%m%d")
    run_query_and_dump_to_csv(env, query, filename)

def run_query_and_dump_to_csv(env, query, filename):
    # Instantiates a client
    client = bigquery.Client()

    # The name for the new dataset
    bucket_name = env['bucket']
    dataset_id = env['bq_dataset']
    events_temp_table_name = 'events_' + str(int(time.time()))

    # Prepares a reference to the new dataset
    dataset_ref = client.dataset(dataset_id)
    table_ref = dataset_ref.table(events_temp_table_name)
    job_config = bigquery.QueryJobConfig()
    job_config.destination = table_ref

    query_job = client.query(query,location="US", job_config=job_config)
    query_job.result()
    print("Dumped events to table {}".format(table_ref.path))

    events_csv_file = 'gs://{}/{}'.format(bucket_name, filename)

    extract_job = client.extract_table(table_ref, events_csv_file, location="US")
    extract_job.result()
    print('Exported {}.{} to {}'.format(dataset_id, events_temp_table_name, events_csv_file))

    client.delete_table(table_ref)

    print('Table {}:{} deleted.'.format(dataset_id, events_temp_table_name))


def generate_events_reports(request):
    print("Generating event reports {}".format(request))
    parsed_url = urlparse(request.url)
    parsed_query = parse_qs(parsed_url.query)
    print("Parsed query: ".format(parsed_query))
    env = {
        'bucket': (parsed_query['bucket'][0] or 'dream-assets-project'),
        'bq_dataset': (parsed_query['bq_dataset'][0] or 'dream-assets-dataset'),
        'bq_table': (parsed_query['bq_table'][0] or 'measurements')
    }
    print("Using env {}".format(env))
    tag_events_per_day(env)
    tag_events_per_hour(env)
    hub_events_per_day(env)
    hub_events_per_hour(env)

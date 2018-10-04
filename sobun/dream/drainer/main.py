"""
Cloud Function: Background Function

For details, visit:
https://cloud.google.com/functions/docs/writing/background#functions_background_parameters-python
"""

from google.cloud import bigquery


client = bigquery.Client()
dataset_id = 'dream_assets_raw_packets'
table_id = 'measurements_table'
table_ref = client.dataset(dataset_id).table(table_id)
table = client.get_table(table_ref)

def run(data, context):

    rows = [
            (data['tag_id'], data['measurements'])
    ]

    errors = client.insert_rows(table, rows)
    assert errors == []

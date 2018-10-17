# This file goes is our Google Cloud Function for PubSub
# Specifically, it subs to the RasPi's pub 

"""
Cloud Function: Background Function

For details, visit:
https://cloud.google.com/functions/docs/writing/background#functions_background_parameters-python
"""

import base64

from google.cloud import bigquery

import helpers

client = bigquery.Client()

# TODO put in config file too 
dataset_id = 'dream_assets_dataset'
table_id = 'dream_measurements_table'
table_ref = client.dataset(dataset_id).table(table_id)
table = client.get_table(table_ref)


# Run under Python 3.7 runtime
def run(data, context):

    print("data published: ", data)
    attributes = data['attributes']
    hub_id = attributes["hub_id"]

    # data['data'] is somehow base64 encoded
    payloads = base64.b64decode(data['data']).decode('utf-8')
    lines = payloads.split('\n')
    rows = []
    for line in lines:
        row = line.split(',')
        timestamp, tag_id, measurements, hci, rssi = row
        bigquery_row = (tag_id, measurements, hub_id, int(timestamp), int(rssi), int(hci))
        rows.append(bigquery_row)

    # BigQuery has a limit of 10K insert at a time
    batches = helpers.batch(rows, 10000)
    for batch in batches:
        # try to insert this row. If there're errors, return it as a list
        errors = client.insert_rows(table, list(batch))
        assert errors == [], errors

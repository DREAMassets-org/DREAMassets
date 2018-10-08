# This file goes is our Google Cloud Function for PubSub
# Specifically, it subs to the RasPi's pub 

"""
Cloud Function: Background Function

For details, visit:
https://cloud.google.com/functions/docs/writing/background#functions_background_parameters-python
"""

import base64
import json

from google.cloud import bigquery

client = bigquery.Client()
dataset_id = 'dream_assets_raw_packets'
table_id = 'measurements_table'
table_ref = client.dataset(dataset_id).table(table_id)
table = client.get_table(table_ref)


# Run under Python 3.7 runtime
def run(data, context):

    print("data published: ", data)

    # data['data'] is somehow base64 encoded
    payload = base64.b64decode(data['data']).decode('utf-8')
    row = json.loads(payload)
    hub_id = row.get('hub_id', None)
    tag_id = row['tag_id']

    #TODO process measurements into meaningful values here
    measurements = row['measurements']
    
    timestamp = row['timestamp']
    rssi = row['rssi']
    rows = [(tag_id, measurements, hub_id, timestamp, rssi)]

    # what does this do? 
    errors = client.insert_rows(table, rows)
    assert errors == [], errors

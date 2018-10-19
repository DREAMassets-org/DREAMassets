# This script was for development purposes but is no longer useful
#
# During development, we streamed small amounts of data to BigQuery (~100 measurements every few seconds)
# based on that expectation, this script showed which Hubs were offline / failing
# DREAM now uploads 20k measurements every hour-ish, so this script is moot. 
#
# This file queries BigQuery to see updates to our table 
# We use it to monitor the system status 

from __future__ import print_function

from time import sleep
import sys

from google.cloud import bigquery

query = """
SELECT hub_id,
    count(hub_id) as count
FROM `dream-assets-project.dream_assets_raw_packets.measurements_table`
    GROUP BY hub_id
    ORDER BY hub_id;
"""

client = bigquery.Client()

# TODO let's put these ID's in a config file to simplicity 
dataset_id = 'dream_assets_raw_packets'
table_id = 'measurements_table'
table_ref = client.dataset(dataset_id).table(table_id)
table = client.get_table(table_ref)

# Display the hub name, count of payloads since starting the script, and total # of payloads ever
#
# Example:
# sueno     0    1234
# sueno     2    1236
if __name__ == "__main__":
    first_counts = {}  #a set of first_counts for all Hubs 
    while True:
        job = client.query(query)
        rows = job.result()
        for row in rows:
            if row.hub_id is not None:
                #fcount is the first count for each individual Hub (from the set of first_counts)
                fcount = first_counts.get(row.hub_id, None) 
                if not fcount:
                    fcount = row.count
                    first_counts[row.hub_id] = row.count

                delta = row.count - fcount
                sys.stdout.write("{hub_id: <15} {delta: <15} {count: <15}\n".format(
                    hub_id=row.hub_id, count=row.count, delta=delta))

        # we use stdout so the output is grep'able
        # python -m dream.healthz | grep sueno         
        sys.stdout.write("\n")
        sys.stdout.flush()
        sleep(1)

# TODO catch SIGINTs for a graceful exit 

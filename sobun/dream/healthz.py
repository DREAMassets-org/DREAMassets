from __future__ import print_function

from time import sleep

from google.cloud import bigquery

query = """
SELECT hub_id,
    count(hub_id) as count
FROM `dream-assets-project.dream_assets_raw_packets.measurements_table`
    GROUP BY hub_id
    ORDER BY hub_id;
"""

client = bigquery.Client()
# TODO let's put these ID's in an env.py file to simplicity 
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
    first_counts = {}  #what's the difference btw first_counts and fcount? Can we clarify var names?
    while True:
        job = client.query(query)
        rows = job.result()
        print("")
        for row in rows:
            if row.hub_id is not None:
                fcount = first_counts.get(row.hub_id, None)
                if not fcount:
                    fcount = row.count
                    first_counts[row.hub_id] = row.count

                delta = row.count - fcount
                print("{hub_id: <15} {delta: <15} {count: <15}".format(
                    hub_id=row.hub_id, count=row.count, delta=delta))

        sleep(1)

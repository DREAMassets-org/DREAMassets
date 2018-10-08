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
dataset_id = 'dream_assets_raw_packets'
table_id = 'measurements_table'
table_ref = client.dataset(dataset_id).table(table_id)
table = client.get_table(table_ref)

if __name__ == "__main__":
    first_counts = {}
    while True:
        job = client.query(query)
        rows = job.result()
        for row in rows:
            if row.hub_id is not None:
                fcount = first_counts.get(row.hub_id, None)
                if not fcount:
                    fcount = row.count
                    first_counts[row.hub_id] = row.count

                delta = row.count - fcount
                sys.stdout.write("{hub_id: <15} {delta: <15} {count: <15}\n".format(
                    hub_id=row.hub_id, count=row.count, delta=delta))

        sys.stdout.write("\n")
        sys.stdout.flush()
        sleep(1)
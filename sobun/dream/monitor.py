from time import sleep
import sys

from google.cloud import bigquery

from dream.drainer import config

query = """
SELECT
    hub_id,
    FORMAT_DATETIME(
        "%a %h %d, %Y - %I:%M:%S %p",
        DATETIME(TIMESTAMP_SECONDS(max(timestamp)), "America/Los_Angeles")) AS latest_update
from `dream-assets-project.dream_assets_dataset.dream_measurements_table`
GROUP BY hub_id
ORDER BY hub_id
"""

if __name__ == "__main__":
    client = bigquery.Client()
    dataset_id = config.BIG_QUERY_DATASET_ID
    table_id = config.BIG_QUERY_TABLE_ID
    table_ref = client.dataset(dataset_id).table(table_id)
    table = client.get_table(table_ref)

    job = client.query(query)
    rows = job.result()
    for row in rows:
        sys.stdout.write("{hub_id: <15}  {latest_update: <15}\n".format(
            hub_id=row.hub_id, latest_update=row.latest_update))

    sys.stdout.write("\n")
    sys.stdout.flush()


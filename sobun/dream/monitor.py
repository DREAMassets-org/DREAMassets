from time import sleep
import sys

from google.cloud import bigquery


# TODO the dataset and table are hardcoded 
query = """
SELECT
    hub_id,
    count(hub_id) as total_count,
    FORMAT_DATETIME(
        "%a %h %d, %Y - %I:%M:%S %p",
        DATETIME(TIMESTAMP_SECONDS(max(timestamp)), "America/Los_Angeles")) AS latest_update
from `dream-assets-project.dream_assets_dataset.dream_measurements_table`
GROUP BY hub_id
ORDER BY hub_id
"""

if __name__ == "__main__":
    client = bigquery.Client()
    dataset_id = 'dream_assets_dataset'
    table_id = 'dream_measurements_table'
    table_ref = client.dataset(dataset_id).table(table_id)
    table = client.get_table(table_ref)

    job = client.query(query)
    rows = job.result()
    sys.stdout.write("{hub_id: <15}  {latest_update: <35} {total_count: <15}\n".format(
        hub_id="Hub ID",
        latest_update="Latest Update",
        total_count="Total Count"
    ))
    for row in rows:
        sys.stdout.write("{hub_id: <15}  {latest_update: <35} {total_count: <15}\n".format(
            hub_id=row.hub_id,
            total_count=row.total_count,
            latest_update=row.latest_update))

    sys.stdout.write("\n")
    sys.stdout.flush()


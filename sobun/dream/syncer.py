# syncer script pops data from the queue and publishes to google

# we use celery "workers" to run the job of publishing (pushing payloads) to PubSub
# third party library, 
# explained in https://celery.readthedocs.io/en/latest/getting-started/first-steps-with-celery.html#first-steps
from celery import Celery

from dream.batcher import dbconnect, insert

app = Celery()
# use the celeryconfig.py file to get the queue server and other settings 
app.config_from_object('celeryconfig')  


@app.task
def batch(bundle, hci=0):
    rows = []
    for packet in bundle:
        # Fujitsu's mfr_data value has measurements in the last 16 characters (8 bytes)
        mfr_data = packet.pop('mfr_data')
        measurements = mfr_data[-16:]
        row = {
            "timestamp": packet["timestamp"],
            "tag_id": packet["tag_id"],
            "measurements": measurements,
            "hci": hci,
            "rssi": packet["rssi"]
        }
        rows.append(row)

    dbconn = dbconnect()
    insert(rows, dbconn.cursor(), many=True)
    dbconn.commit()
    dbconn.close()

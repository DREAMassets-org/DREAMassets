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
def push(packet, hci=0):
    # Publish packet data to Google's PubSub

    # Lazy import send_data so only the Celery workers need Google Authz
    # Without this in push, then the sniffer.py file would also need Google Authz 
    from dream.gpub import send_data

    # We pass packets to send_data, 
    # which cleans the packet to create a payload
    # and then publishes the payload to PubSub 
    send_data(packet, hci)


@app.task
def batch(packet, hci=0):
    dbconn = dbconnect()
    # Fujitsu's mfr_data value has measurements in the last 16 characters (8 bytes)
    mfr_data = packet.pop('mfr_data')
    measurements = mfr_data[-16:]
    row = {
        "batch_id": 0,
        "timestamp": packet["timestamp"],
        "tag_id": packet["tag_id"],
        "measurements": measurements,
        "hci": hci,
        "rssi": packet["rssi"],
        "synced": False
    }
    insert(row, dbconn.cursor())
    print('inserting: ', row)
    dbconn.commit()
    dbconn.close()

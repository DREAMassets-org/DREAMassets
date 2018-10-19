# syncer script pops data from the queue and publishes to google
#
# TODO rename syncer.py to workers.py since it's really just where we create celery workers

# The naming convention is: 
#   BUNDLING packets before inserting into the queue
#   BATCHING payloads before publishing them to a topic in Google PubSub

# we use celery "workers" to run the job of publishing (pushing payloads) to PubSub
# third party library, 
# explained in https://celery.readthedocs.io/en/latest/getting-started/first-steps-with-celery.html#first-steps
from celery import Celery

from dream.batcher import dbconnect, insert

app = Celery()
# use the celeryconfig.py file to get the queue server and other settings 
app.config_from_object('celeryconfig')  

 
# The celery worker will:
#   1. receive a bundle of packets  
#   2. convert each packet in the bundle into a payload (row) by extracting measurements from mfr_data
#   3. insert the list of rows (payloads) into the database 
#   
# TODO rename batch() to insert_payloads_in_db() 
@app.task
def batch(bundle, hci=0):
    rows = []
    # extract each packet from the bundle of packets
    # convert packets into payloads and add rows of payloads to the database
    for packet in bundle:
        # Fujitsu's mfr_data value has measurements in the last 16 characters (8 bytes)
        mfr_data = packet.pop('mfr_data')
        measurements = mfr_data[-16:]
        # a row is a payload 
        row = {  
            "timestamp": packet["timestamp"],
            "tag_id": packet["tag_id"],
            "measurements": measurements,
            "hci": hci,
            "rssi": packet["rssi"]
        }
        rows.append(row)

    dbconn = dbconnect()
    # add the list of rows (payloads) to the SQLite database  
    insert(rows, dbconn.cursor(), many=True)
    dbconn.commit()
    dbconn.close()

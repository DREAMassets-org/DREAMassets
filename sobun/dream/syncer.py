# syncer script pops data from the queue and publishes to google

# we use celery "workers" to run the job of publishing (pushing payloads) to PubSub
# third party library, 
# explained in https://celery.readthedocs.io/en/latest/getting-started/first-steps-with-celery.html#first-steps
from celery import Celery

app = Celery('syncer', broker='redis://localhost:6379')


@app.task
def push(packet):
    # Publish packet data to Google's PubSub

    # Lazy import send_data so only the Celery workers need Google Authz
    from dream.gpub import send_data

    # We pass packets to send_data, 
    # which cleans the packet to create a payload
    # and then publishes the payload to PubSub 
    send_data(packet)

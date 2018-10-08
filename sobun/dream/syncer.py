# syncer script pops data from the queue and publishes to google

# third party library
from celery import Celery

app = Celery('syncer', broker='redis://localhost:6379')


@app.task
def push(packet):
    # Publish packet data to Google's PubSub

    # Lazy import send_data so only the Celery workers need Google Authz
    from dream.gpub import send_data

    send_data(packet)

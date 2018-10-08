# syncer script pops data from the queue and publishes to google

# third party library, explained in https://celery.readthedocs.io/en/latest/getting-started/first-steps-with-celery.html#first-steps

from celery import Celery

app = Celery('syncer', broker='redis://localhost:6379')


@app.task
def push(packet):
    # Publish packet data to Google's PubSub

    # Lazy import send_data so only the Celery workers need Google Authz
    from dream.gpub import send_data

    send_data(packet)

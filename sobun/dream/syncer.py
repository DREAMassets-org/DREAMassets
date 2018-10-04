# syncer script pops data from the queue and publishes to google

# third party library
from celery import Celery

# our project DREAM library
from dream.gpub import send_data

app = Celery('scanner', broker='redis://localhost:6379')


@app.task
def push(packet):
    # publish packet data to Google's pubsub
    send_data(packet)
    return 'push packet into the queue'

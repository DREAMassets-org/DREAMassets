from celery import Celery

app = Celery('scanner', broker='redis://localhost:6379')


@app.task
def push(packet):
    # publish packet data to Google's pubsub
    return 'push packet into the queue'

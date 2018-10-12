# This file configures celery. Celery looks for this file by default. 

# use the redis server for the queue
broker_url = 'redis://localhost:6379/0'

# restart the worker (on the syncer service) after 10k tasks (packets)
# this is a work-around for why the worker hangs after publishing to PubSub for a while 
worker_max_tasks_per_child = 10000

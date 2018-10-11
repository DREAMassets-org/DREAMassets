broker_url = 'redis://localhost:6379/0'
result_backend = 'redis://'

# task results will be discarded after 30 seconds
# to avoid out of memory error
result_expires = 30

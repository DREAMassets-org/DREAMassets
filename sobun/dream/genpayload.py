import redis

r = redis.StrictRedis()

with open('./sample_payloads.txt') as data:
    lines = data.readlines()
    r.rpush('celery', *lines)

print("Total Payload count: {}".format(r.llen('celery')))

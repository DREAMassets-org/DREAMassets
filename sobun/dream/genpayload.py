import redis

from dream.syncer import push

r = redis.StrictRedis()
dummy_payload = {
        "tag_id": "d5a0e5b5ffc1",
        "rssi": -63,
        "timestamp": 1539206911,
        "mfr_data": "5900010003000300910370003f0030f8",
        }


if __name__ == "__main__":
    hci = 0
    for i in xrange(10000):
        push.delay(dummy_payload, 0)

    print("Total Payload count: {}".format(r.llen('celery')))

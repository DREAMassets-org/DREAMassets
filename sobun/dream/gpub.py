from __future__ import print_function

import json
import socket

from google.cloud import pubsub
from google.cloud.pubsub import types

HUB_ID = socket.gethostname()

topic = "projects/dream-assets-project/topics/tags-dev"
publisher = pubsub.PublisherClient(
    batch_settings=types.BatchSettings(max_messages=50), )


def send_data(packet):
    payload = clean(packet)
    future = publisher.publish(topic, payload)
    print("sending payload: ", payload)
    msg_id = future.result()
    if not msg_id:
        # TODO make celery retry
        # raise "Something went wrong. Try again"
        pass


def clean(packet):
    # NOTE payload must be bytestring

    # We add metadata here so we don't have change the schema of the "queue"
    # packet for celery
    packet['hub_id'] = HUB_ID

    mfr_data = packet.pop('mfr_data')
    measurements = mfr_data[-16:]
    packet['measurements'] = measurements
    payload = json.dumps(packet)
    return payload


if __name__ == "__main__":
    tag_id = 1
    while True:
        tag_id += 1
        packet = {
            "hub_id": HUB_ID,
            "tag_id": tag_id,
            "rssi": 2,
            "mfr_data": "foobarhexcode"
        }
        send_data(packet)

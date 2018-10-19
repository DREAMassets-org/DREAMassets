# This file sends data from the RasPi to Google PubSub
#
# The dataflow in DREAM is bleAdvertisement -> packet -> payload
# At this point in the project, DREAM sends *payloads* via PubSub to BigQuery

from __future__ import print_function

import json
import socket
import copy

from google.cloud import pubsub
from google.cloud.pubsub import types

from dream import config

# During setup, we set the RasPi's hostname to the Hub ID  
HUB_ID = socket.gethostname()

# The Hub publishes to this topic on PubSub 
TOPIC = "projects/{}/topics/{}".format(config.GOOGLE_PROJECT_ID, config.GOOGLE_PUBSUB_TOPIC)

# When the batch is created, it begins a countdown that publishes the batch
# once sufficient time has elapsed (by default, this is 0.05 seconds).
# We batch for 10 seconds worth of data coming out of the redis queue.
publisher = pubsub.PublisherClient(
        # TODO when we tune the system, we'll want to adjust these values 
        batch_settings=types.BatchSettings(max_messages=50, max_latency=10), )


# reduce the packet to a payload and send it to BigQuery via PubSub
# syncer.py calls this function 
def send_data(packet, hci):

    # We make a copy of the original packet, so we can push it back into the queue, if necessary
    original_packet = copy.deepcopy(packet)

    # After trying to publish to PubSub, Google returns a result 
    def on_result(future):
        # the result is an integer or None (indicating failure)
        msg_id = future.result()
        # if the publish failed, push the packet back into the queue
        if not msg_id:
            from dream.syncer import push
            push.delay(original_packet)
            print("Message NOT created on Google Pub/Sub. Repush the packet back into the queue")
        else:
            print('Created Cloud Pub/Sub msg_id: {}'.format(msg_id))

    # We reduce the packet to a payload, try to publish it and wait for the callback    
    payload = clean(packet)
    future = publisher.publish(TOPIC, payload)
    future.add_done_callback(on_result)
    print("sending payload from HCI {hci}: {payload}".format(hci=hci, payload=payload))


# TODO in a refactor: make clean a private function since it's only used by send_data 
def clean(packet):
    # NOTE payload must be bytestring

    # We add metadata here so we don't have change the schema of the "queue" packet for celery
    # It's faster to tack on hub ID here, rather than when pushing into the queue 
    # TODO if we change the format of the PubSub message, just send the HUB_ID once, rather than with each packet
    packet['hub_id'] = HUB_ID

    # Fujitsu's mfr_data value has measurements in the last 16 characters (8 bytes)
    mfr_data = packet.pop('mfr_data')
    measurements = mfr_data[-16:]
    packet['measurements'] = measurements

    payload = json.dumps(packet)
    return payload


def send_batch(payload):
    publisher = pubsub.PublisherClient()
    future = publisher.publish(TOPIC, payload, hub_id=HUB_ID)
    return future.result()


# for development purposes: 
# the code below will only be run if we invoke it from the command line: python -m dream.gpub
# this block of code allows us to test gpub from our laptop, without a RasPi 
if __name__ == "__main__":
    from time import time 
    tag_id = 1
    while True:
        tag_id += 1
        packet = {
            "hub_id": HUB_ID,
            "tag_id": tag_id,
            "rssi": 2,
            "measurements": "foobarhexcode",
            "timestamp": time(),
        }
        send_data(packet)









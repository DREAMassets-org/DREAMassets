# This file sends data from the RasPi to Google PubSub
#
# The dataflow in DREAM is bleAdvertisement -> packet -> payload
# At this point in the project, DREAM sends *payloads* via PubSub to BigQuery

from __future__ import print_function

import base64
import json
import socket

from google.oauth2 import service_account
import googleapiclient.discovery

from dream import config

# During setup, we set the RasPi's hostname to the Hub ID  
HUB_ID = socket.gethostname()

SCOPES = ['https://www.googleapis.com/auth/pubsub']

# The Hub publishes to this topic on PubSub 
TOPIC = "projects/{}/topics/{}".format(config.GOOGLE_PROJECT_ID, config.GOOGLE_PUBSUB_TOPIC)

def send_batch(payload):
    data = {
        "messages": [
            {
                "data": base64.b64encode(payload),
                "attributes": {
                    "hub_id": HUB_ID
                }
            }
        ]
    }

    # service account file is the same as the secret json file
    SERVICE_ACCOUNT_FILE = config.GOOGLE_APPLICATION_CREDENTIALS
    credentials = service_account.Credentials.from_service_account_file(
            SERVICE_ACCOUNT_FILE, scopes=SCOPES)

    try:
        pubsub = googleapiclient.discovery.build('pubsub', 'v1', credentials=credentials)
        res = pubsub.projects().topics().publish(topic=TOPIC, body=data).execute()
        return res
    except Exception as e:
        print("Unable to publish data to Google Cloud due to network error: {}".format(e))
        return

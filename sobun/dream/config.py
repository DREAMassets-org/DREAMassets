import os


GOOGLE_PROJECT_ID = os.environ.get("GOOGLE_PROJECT_ID", "dream-assets-project")
GOOGLE_PUBSUB_TOPIC = os.environ.get("GOOGLE_PUBSUB_TOPIC ", "batched-payloads")
BATCH_SIZE = os.environ.get("BATCH_SIZE", "20000")
DREAM_PUBSUB_TIMEOUT = os.environ.get("DREAM_PUBSUB_TIMEOUT", "300")

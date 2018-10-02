# Hardening BLE Packet

## Decouple packects data collection from data publishing

At a high level, we will put BLE packets into a redis queue. We publish the data by popping off the queue and send the data to Google Cloud PubSub.

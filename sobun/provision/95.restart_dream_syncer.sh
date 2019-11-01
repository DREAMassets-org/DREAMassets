#!/bin/bash

# When there's a change to the network connectivity, i.e., cellular comes online/offline,
# this bash script restarts the DREAM syncer that sends data to Google Cloud.

# Copy this file to this directory: /etc/NetworkManager/dispatcher.d
# Run: chown root:root /etc/NetworkManager/dispatcher.d/95.restart_dream_syncer.sh
# Run: chmod +x /etc/NetworkManager/dispatcher.d/95.restart_dream_syncer.sh


IF=$1
STATUS=$2

logger -s "DREAM: $IF status is now $STATUS"
systemctl restart dream-syncer.service
logger -s "DREAM: dream-syncer has been restarted"

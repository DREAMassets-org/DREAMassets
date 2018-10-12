#!/bin/bash
# to operate at "peak hours", the timer requires this file 

# start the dream-sniffer to gather BLE advertisements as a systemd service 
systemctl start dream-sniffer@{0..3}

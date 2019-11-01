#!/bin/bash
# to operate at "peak hours", the timer requires this file 

# stop the dream-sniffer service 
systemctl stop dream-sniffer@{0..3}

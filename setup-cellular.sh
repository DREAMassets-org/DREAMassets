#!/bin/bash

# Run Soracom's script to have a cellular dongle with their SIM card only operate in 3G mode
sudo ./soracom/setup_air_3G_only.sh

# Copy files to automatically run when the cell network connects and disconnects
sudo cp ./soracom/connected /etc/ppp/ip-up.d/
sudo cp ./soracom/disconnected /etc/ppp/ip-down.d/

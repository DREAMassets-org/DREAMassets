#!/bin/bash

sudo cp ./dream-sniffer.service /etc/systemd/system/
sudo cp ./dream-syncer.service /etc/systemd/system/

sudo systemctl daemon-reload

sudo systemctl enable dream-sniffer.service
sudo systemctl enable dream-syncer.service

sudo systemctl restart dream-sniffer.service
sudo systemctl restart dream-syncer.service

#!/bin/bash

sudo cp ./dream-sniffer@.service /etc/systemd/system/
sudo cp ./dream-syncer.service /etc/systemd/system/
sudo cp ./dream-batcher.service /etc/systemd/system/
sudo cp ./dream-batcher.timer /etc/systemd/system/

sudo systemctl daemon-reload

sudo systemctl enable dream-sniffer@{0..3}.service
sudo systemctl enable dream-syncer.service
sudo systemctl enable dream-batcher.timer

sudo systemctl restart dream-sniffer@{0..3}.service
sudo systemctl restart dream-syncer.service
sudo systemctl start dream-batcher.timer

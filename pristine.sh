#!/bin/bash

# We run this script before creating a "sleep" Hub 

echo "Updating the daemon services and peak hour timer services"
/home/pi/repo/dream.git/daemonize.sh
/home/pi/repo/dream.git/peak-hour.sh
echo

echo "setting up the cell modem and associated scripts for connect and disconnect"
sudo /home/pi/repo/dream.git/setup-cellular.sh
echo

echo "Stopping the sniffer and syncer processes"
sudo systemctl stop dream-syncer
sudo systemctl stop dream-sniffer@{0..3}
echo

echo "Flushing all data from the redis queue and assicated list of results"
redis-cli flushall
echo

echo "(re-)creating the SQLite db schema"
( cd sobun && ../setup-sqlite-db.sh )
echo

echo
echo "To create a pristine sleep Hub, run this script and:" 
echo "(1) You should check dream files are current in "
echo "ls /etc/systemd/system/"
echo
echo "(2) You should check there are no log files in"
echo "ls /var/log | grep syslog"
echo 
echo "(3) You should check wifi networks are limited"
echo "cat /etc/wpa_supplicant/wpa_supplicant.conf "
echo
echo "(4) You should validate there's a vm.overcommit_memory=1 in"
echo "cat /etc/sysctl.conf | grep overcommit"
echo
echo "(5) You should validate there's google credentials"
echo "cat ~/secrets/google-credentials.secret.json"
echo
echo "(6) You should ensure the config.py file points to your GCP PubSub topic"
echo "cat ~/repo/dream.git/sobun/dream/config.py"
echo
echo " AFTER cloning the new SD Card and creating the new Hub:"
echo "(1) You should check there's a BLE USB dongle on the Hub"
echo
echo "(2) Change the hostname from sleep to something unique"
echo "sudo raspi-config"
echo "select 2 Network Options then N1 Hostname"
echo "Validate: the new Hub is working when payloads arrive in BigQuery"
echo 

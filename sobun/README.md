# README for the DREAM project
#### _Sobun style :)_

The DREAM project is an IoT system to gather environmental data from assets such as items in a warehouse. Physically, the project consists of (1) Tags with sensors that broadcast BLE advertisements containing measurements, (2) Hubs that route the data and (3) Cloud storage and analysis.  Hubs are Raspberry Pi machines with SORACOM cellular dongles.  Cloud is Google PubSub, Cloud Function, and BigQuery. 

Both the Raspberry Pi and Google Cloud have:

1. Provisioning
2. Applications
3. Deployment

## Data structure
### `bleAdvertisement` -> `packet` -> `payload`

We're using [bluepy](https://ianharvey.github.io/bluepy-doc/index.html) to interface with Bluetooth in advertising mode. All BLE devices emit a **`BLE advertisent`** with lots of data, including the environmental measurements pertinent to DREAM as well as less important details, such as `adtype`. On the Hub, `sniffer.py` puts a **`packet`** of the data DREAM needs in a queue. Then `syncer.py` reduces the packet to a **`payload`** and publishes the payloads to the cloud. 

Here's the relevant data in the `bleAdvertisement`: 

* `addr` is a 6-byte (12-character) MAC **address** of the BLE device, which is the `tag_ID` in DREAM. 
* `rssi` is the 1-byte (2-character) Received Signal Strength Indicator, a relative metric.
* `mfr_data` is 16-byte (32-character) blob of hex data defined by the manufacturer. For Tags in DREAM, `mfr_data` looks like `5900 010003000300 1d04 5900 0a00 4608` where:
  * `5900` is junk 
  * `010003000300` is the unique identifier for the Tags
  * `1d04 5900 0a00 4608` are sensor **`measurements`** for temp, x-, y-, and z-acceleration.

Here's the data when `sniffer.py` creates a **packet**: 

* `tag_ID ` a unique identifier, the BLE MAC address
* `timestamp` when the BLE advertisement arrived at the Hub
* `rssi` signal strength
* `hci` is the host-control interface number of the BLE chip
* `mfr_data` in hex which includes an identifier and measurements


Here's the data when `syncer.py`creates a **payload**:

* `tag_ID` 
* `timestamp`
* `rssi` 
* `hci` is the host-control interface number of the BLE chip
* `measurements` in hex which are just 16 characters (8 bytes) of temperature and acceleration data.

## Latest architecture
We're using a queue to decouple sniffing BLE from publishing to the cloud.  

* `sniffer.py` pushes packets into the queue  
* **Redis** holds the queue   
* In `syncer.py`, **Celery "workers"** pop packets from the queue, reduce the packets to payloads and send payloads to the cloud. 


## Here's how `bluepy` works in the DREAM project:  

* A `scanner` object is used to [scan](https://ianharvey.github.io/bluepy-doc/scanner.html) for BLE devices which are broadcasting advertising data.  `Scanner` is designed around the use case of scanning for 10 seconds to find a device to connect with. For DREAM, we just want to scan continously, so we're using it slightly differently than its core use case.
  * Before DREAM can scan, DREAM must define the delegate object where `scanner` will deliver the BLE advertisements. 
  * To start the scan, DREAM needs to run `clear()`, `start()` and then within a `while true` run `process()`.   `process()` has a default 10-second timeout so that's why it's in the infinite loop.  
  * DREAM doesn't use `scan()` because of its default timeout.  
* Bluepy finds "BLE broadcasts (advertisements)" and stores their data in the `ScanEntry` object. Bluetooth has defined [more than 20](https://www.bluetooth.com/specifications/assigned-numbers/generic-access-profile) types of data.   
  * The method `getScanData()` returns for each tag a tripple with advertising type, description and value: `(adtype, desc, value)`. DREAM only uses the manufacturer-defined data with Advertising Data type `adtype == 255` (255 is 0xFF in hex) which correspends to the description `desc == "Manufacturer"`. There are many BLE devices broadcasting with manufacturer data, so DREAM filters for the regular expression (regex) that corresponds to the Tags: `010003000300`.  
  * Additionally, DREAM needs the `Tag ID`, what bluepy calls the MAC address of the BLE device which DREAM gets from the `bleAdvertisement.addr` property. 
* The `DefaultDelegate` class has `DefaultDelegate()`
to initialise the instance of the delegate object. 
  * The `scanner` object uses the `handleDiscovery()` method to send data to the `delegate` when the `scanner` discovers a new advertisement. `handleDiscovery()` has the `scanEntry` argument containing device information and advertising data.   
  
  
### We validated our understanding of the data with `test_sniffer.py`
For a Tag with regex `010003000300`, there's a list of values, a MAC address, an AD type, a description, and a value containing the relevant data. The script prints "push to the celery queue" to show proper identification.

```   
values: ['04', '59000100030003001d0459000a004608']
address: fd:d5:77:79:1b:47
AD type: 255
desc: Manufacturer
value: 59000100030003001d0459000a004608
push to the celery queue
```  

For BLE devices that aren't Tags, the data looks similar:

```
values: ['06', '4c0010020b00']
address: 8c:85:90:cc:3f:66
AD type: 255
desc: Manufacturer
value: 4c0010020b00

values: ['06', '4c0010020b00']
address: dc:a9:04:8f:84:68
AD type: 255
desc: Manufacturer
value: 4c0010020b00

values: ['750042040180607c6456361fd97e6456361fd801000000000000']
address: 7c:64:56:36:1f:d9
AD type: 255
desc: Manufacturer
value: 750042040180607c6456361fd97e6456361fd801000000000000
```

-----------------------------


# Build a Hub from Scratch

The easiest way to interface with the RasPi by physically attaching an ethernet cable between the RasPi and your MacBook. On your MacBook enable `Internet Sharing` per [this tutorial](https://medium.com/@tzhenghao/how-to-ssh-into-your-raspberry-pi-with-a-mac-and-ethernet-cable-636a197d055). The tutorial goes into detail on using `nmap` to find your RasPi, but it's easiest to just SSH in:

```
ssh pi@raspberrypi.local
```

Where the RasPi's default `hostname` is `raspberrypi` but you can change it to `sueno` or whatever you like. 


You can also SSH into the RasPi by connecting your laptop and the RasPi to the same WiFi network. When connected you can try using `ssh pi@sueno.local`. However, sometimes the router changes the mapping between the `hostname` and IP address. When that happens you can use the LAN IP address. Search for the devices on the LAN using:

```
ifconfig
```
to get the IP address of the LAN. Something like `10.4.8.1`. Then put that into `nmap`: 

```
nmap -sn 10.4.8.0/24
```

You can then run `arp` to see just the IP addresses of the active devices:
```
arp -a
```

So you could `ssh pi@10.4.8.68`.  There's a mapping from `sueno.local` to `10.4.8.68` that sometimes breaks, so by going direct to IP address, you can work around the problem.  Annoyingly, the WiFi method doesn't always work, which is why ethernet cable is easiest. 


## Provisioning RasPi: Get the packages
The DREAM project uses Linux on the Raspberry Pi.  Disable Wolfram since it comes pre-loaded and it's ridiculously slow to update (less than 100kb/sec) and not used in this project. 

```
sudo apt-get update  
```

```
sudo apt-mark hold wolfram-engine
```

```
sudo apt-get upgrade -y
```


Get glib2.0, Google Cloud PubSub, BLE, python daemon, redis and virtualenv: 
```
sudo apt-get install libglib2.0-dev -y
```
```
sudo pip install google-cloud-pubsub
```
```
sudo pip install bluepy
```
```
sudo pip install python-daemon
```

```
sudo apt-get install redis-server -y
```
```
sudo pip install virtualenv   
```


Get the latest `network-manager` software which we'll use for the SORACOM cellular connection:   

```  
sudo apt-get install network-manager -y
```  

_Debug:_ Note that this script restarts the network service, so it might hang and kick you off the network. Don't worry about it -- just close the Terminal window and log back in to the RasPi.  




## Provisioning RasPi: Get the files and folders

The RasPi comes with many pre-installed folders. Remove all of them (except Desktop) to clean up the home directory.

```
rm -rf Music
```


Modify the `/etc/sysctl.conf` by adding a line with `vm.overcommit_memory=1`:

```
sudo pico /etc/sysctl.conf
```

Then restart sysctl with:
```
sudo sysctl -p /etc/sysctl.conf
```



Create the two directories for DREAM: 

```
mkdir secrets
```

```
mkdir repo
```

Put Google credentials in the `secrets` folder from your computer 

```
scp dream-assets-project-aa551100cc66.json pi@sueno.local:~/secrets/
```
Then on the Pi, rename the file: 
```
mv dream-assets-project-bb550077d3c3.json google-credentials.secret.json
```


Do everything else in the `repo` folder:

```
cd ~/repo
```

```
git clone https://github.com/DREAMassets-org/DREAMassets.git
```

```
mv DREAMassets/ dream.git
```


Go into the git repo and switch to the `hardening` branch:

```
cd dream.git
```

```
git checkout hardening
```

Create the virtual environment from `sobun/`:

```
cd sobun
```

```
virtualenv venv
```
_Debug_: This creates a file structure based on the current directory and path. If you change any of those directory names, it'll break the `venv`. 

Now activate the `venv`:

```
source venv/bin/activate
```

```
source .envrc
```


Install the requirements:

```
pip install -r requirements.txt
```

_Debug:_ If you try to install requirements without `virtualenv`, don't worry because it'll fail. (you'd need to have used `sudo`). Just `activate` and install again.

_Debug:_ The `sniffer.py` and `syncer.py` scripts must be run from the virtual environment. For deployment, DREAM uses `systemd` to launch the `dream-sniffer@{0..3}.service` and `dream-syncer.service`, so it might not seem obvious that the virtual environment is important, but it's crucial.


### Deployment
From the `dream.git/` folder...

Deploy the network manager to restart the sniffer and syncer when there's a change to the network, i.e., the cellular connection drops and then resumes.

```
sudo cp sobun/95.restart_dream_syncer.sh /etc/NetworkManager/dispatcher.d
```

```
sudo chmod +x /etc/NetworkManager/dispatcher.d/95.restart_dream_syncer.sh

```

Deploy the services to start and stop the sniffer and syncer automatically with a deamon. Deploy the services to start and stop the Hub only during meaningful hours. This also clears out any queued up data: 

```
./pristine.sh

```

### Setup Soracom

Setup an APN (Access Point Name) for the SORACOM SIM to connect to the SORACOM mobile network

```
sudo nmcli con add type gsm ifname "*" con-name soracom apn soracom.io user sora password sora  
```
This should give you a response like `Connection 'soracom' (3cbecb73-2f6c-48f9-819a-3e233408d4a0) successfully added.`

Plug in your USB dongle with Soracom SIM card. You should have already registered the SIM card with Soracom.

Restart your Hub.

```  
sudo reboot
```  

Wait for the USB light to flash green and then SSH back into the Pi.  Wait for the light on the SORACOM to go blue and check whether `ifconfig` shows `ppp0` by running the command:

```  
ifconfig
```  

Run the following commands to grab and execute Soracom's helper script. This will make Soracom cell the default internet connection on your Hub.

Go to the directory with the soracom file:

```  
cd ~/repo/dream.git/soracom
```  

Copy the `ppp_route_metric` script to the RasPi startup directory

```  
sudo cp 90.set_ppp_route_metric /etc/NetworkManager/dispatcher.d/
```  

Make the file executable

```  
sudo chmod +x /etc/NetworkManager/dispatcher.d/90.set_ppp_route_metric
```  

Run Soracom's file:
 
```  
sudo /etc/NetworkManager/dispatcher.d/90.set_ppp_route_metric ppp0 up
```  

Restart your Hub.

```  
sudo reboot
```  

SSH back into your Hub and check the routing table, where `ppp0` should be at the top (once the USB has a solid blue light, indicating a Soracom connection).

```  
route -n
```  

Last, to double check, run a `traceroute` to make sure the first hop is Soracom's AWS server in Europe:

```  
traceroute fast.com
```  

Congrats :tada: Happy cell connectivity!  




### Create a clone-able SD Card
Use `SD Clone` to create an exact image of the SD card

* Stop the `sniffer` and `syncer` because they'll add payloads to the queue and their logs build up, which can cause problems.

```
sudo systemctl stop dream-syncer.service
```
```
sudo systemctl stop dream-sniffer@{0..3}
```

* Check the redis queue and purge it

```
redis-cli llen celery
```
```
redis-cli flushall
```


-----------------------------



# Monitor system performance


Set the virtual environment for Google Cloud credentials: 

```
source venv/bin/activate
```

```  
source .envrc
```  

Run the `healthz` script, which returns a list of Hubs and a count of their payloads in BigQuery: 
```  
python -m dream.healthz
```  

Check what's running -- we're daemonizing, so we need to explicitly look! 

```
ps -ef | grep pyth
```

Check on the syncer daemon service:

```
sudo systemctl status dream-syncer.service
```
Click `q` to exit the screen.

Use the `watch` command to see the service send each packet:
```
watch -n0.5 sudo systemctl status dream-syncer.service
```

###Other notes

View the `.envrc` file that shows where to find credentials for Google Cloud:

```  
cat ~/repo/dream.git/sobun/.envrc
```  
Which returns: `export GOOGLE_APPLICATION_CREDENTIALS="./google-credentials.secret.json"`

We looked at system files `networking.service` and `NetworkManager-wait-online.service` in:

```  
cd /etc/systemd/system/network-online.target.wants/
```  
 
# Google Cloud
The DREAM project uses these products in the Google Cloud Platform (GCP):

* **`PubSub`** The Hubs publish data to a PubSub topic, which is the link between the Hubs and the Cloud. 
* **`Cloud Function`** The Function detects a publication, modifies the data, and inserts it into DREAM's database.
*  **`Big Query`** DREAM uses Big Query as its database. 
*  **`Source Repository`** The source code for the `cloud function` is stored here.

  
### PubSub
DREAM uses the topic `projects/dream-assets-project/topics/tags-dev` where the Hub publishes payloads and the Cloud Function subscribes to payloads. 

### Cloud Function
The Cloud function is in `/sobun/dream/drainer`. It receives a payload, processes it into meaningful measurement values, and inserts the values as a row in the database. 

### Source Repository
The source repo holds the code. To update the source repo manually, click `edit` and `save`. 

### Big Query
Big Query holds our data. We created the `dream_assets_dataset` which contains the `dream_values_table`. When you create the table, under schema, choose "Edit as text" and insert the following for the schema:

```sql
hub_id:STRING,tag_id:STRING,temperature:FLOAT,x_accel:FLOAT,y_accel:FLOAT,z_accel:FLOAT,rssi:INTEGER,hci:INTEGER,timestamp:INTEGER
```


Here are relevant queries we use:

```sql
SELECT * FROM `dream-assets-project.dream_assets_raw_packets.measurements_table` where hub_id = "mafarki" and timestamp > 1539644084
```

```sql
SELECT * FROM `dream-assets-project.dream_assets_raw_packets.measurements_table` where timestamp > 1539625646 and timestamp < 1539625746
```


```sql
SELECT t0.hub_id, SUM(t0.rssi) AS t0_qt_ehp4ieeurb, COUNT(FORMAT_TIMESTAMP('%Y%m%d', TIMESTAMP_MICROS(t0.timestamp*1000000))) AS t0_qt_ls5hqceurb, APPROX_COUNT_DISTINCT(FORMAT_TIMESTAMP('%Y%m%d', TIMESTAMP_MICROS(t0.timestamp*1000000))) AS t0_qt_x9b3beeurb FROM `dream-assets-project._c45901274641ddf047eeb498ee472b0d7d5b0321.anon08738b00_6572_422c_9c8e_ed8df51b3ef8` AS t0 GROUP BY t0.hub_id ORDER BY t0_qt_ls5hqceurb DESC;
```

```sql
delete FROM `dream-assets-project.dream_assets_raw_packets.measurements_table` where hub_id = "sleep"
```

```sql
Select DATETIME ( TIMESTAMP_seconds ( max (timestamp) ), "America/Los_Angeles") FROM `dream-assets-project.dream_assets_raw_packets.measurements_table` where hub_id = "ruya"
```

Try a more informative query like the following (you need to update `hub id`, `tag id`, and `timestamp` values)

```sql
SELECT
  DATETIME(PARSE_TIMESTAMP("%s", cast(measurements.timestamp as string)), "America/Los_Angeles") as ts_datetime,
  measurements.*
FROM
  dream_assets_dataset.measurements_table measurements,
WHERE
  measurements.timestamp > 1532538000 # 10am July 25 2018 PST
  and measurements.timestamp < 1532545200 # 12am July 25 2018 PST
  and measurements.tag_id='<tag id>'
  and measurements.hub_id='<hub id>'
ORDER BY timestamp DESC
```




   
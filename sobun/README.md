# Hardening the DREAM project
### Sobun style :)

## Architecture
We're using a queue to decouple sniffing BLE data from publishing to the cloud.  

* We're using `redis` to create the queue   
* `sniffer.py` pushes packets into the queue  
* `syncer.py` pops the packets from the queue, reduces them to payloads and sends payloads to the cloud. 

## Data structure
### `bleAdvertisement` -> `packet` -> `payload`

We're using [bluepy](https://ianharvey.github.io/bluepy-doc/index.html) to interface with Bluetooth in advertising mode. All BLE devices emit a BLE advertisent `bleAdvertisement` with lots of data. There's data we don't care about, such as `adtype`. First, `sniffer.py` puts **packets** of the data we care about in a queue. Then `syncer.py` reduces packets to **payloads** and publishes the payloads to the cloud. 

Here's the relevant data in the `bleAdvertisement`: 

* `addr` is a 6-byte (12-character) MAC **address** of the BLE device, which is the `tag_ID` in DREAM. 
* `rssi` is the 1-byte (2-character) Received Signal Strength Indicator, a relative metric that's unique to RasPi.
* `mfr_data` is 16-byte (32-character) blog of hex data defined by the manufacturer. For Tags in DREAM, `mfr_data` looks like `5900 010003000300 1d04 5900 0a00 4608` where:
  * `5900` is junk 
  * `010003000300` is Fujitsu's unique BLE identifier 
  * `1d04 5900 0a00 4608` are sensor **measurements** for temp, x-, y-, and z-acceleration, which are `measurements` in DREAM.

`sniffer.py` creates a **packet** with `tag_ID `, `rssi`, and `mfr_data`. `sniffer.py` pushes packets into the queue. 

`syncer.py`creates a **payload** with `tag_ID`, `rssi` and `measurements`. `syncer.py` pops packets from the queue, removes the junk and Fujitsu identifier, and publishes payloads to the cloud. 


## Here's how bluepy works in the DREAM project:  

* A `scanner` object is used to [scan](https://ianharvey.github.io/bluepy-doc/scanner.html) for BLE devices which are broadcasting advertising data.  `Scanner` is designed around the use case of scanning for 10 seconds to find a device to connect with. For DREAM, we just want to scan continously, so we're using it slightly differently than its core use case.
  * Before DREAM can scan, DREAM must define the delegate object using `withDelegate` where `scanner` will deliver the BLE advertisements.
  * To start the scan DREAM needs to run `clear()`, `start()` and then within a `while true` run `process()`.   `process()` has a default 10-second timeout so that's why it's in the while loop.  
  * DREAM doesn't use `scan()` because of its default timeout.  
* Bluepy finds "BLE broadcasts" (what DREAM calls `bleAdvertisement`s) and stores their data in the `ScanEntry` object. Bluetooth has defined [more than 20](https://www.bluetooth.com/specifications/assigned-numbers/generic-access-profile) types of data.   
  * The method `getScanData()` returns for each tag a tripple with advertising type, description and value: `(adtype, desc, value)`. DREAM only uses the manufacturer-defined data with Advertising Data type `adtype == 255` (255 is 0xFF in hex) which correspends to the description `desc == "Manufacturer"`. There are many BLE devices broadcasting with manufacturer data, so DREAM filters for the regular expression (regex) that corresponds to the Tags: `010003000300`.  
  * Additionally, DREAM needs the `Tag ID`, what bluepy calls the MAC address of the BLE device which DREAM gets from the `bleAdvertisement.addr` property. 
* The `DefaultDelegate` class has `DefaultDelegate()`
to initialise instance of the delegate object. 
  * The `scanner` object uses tje `handleDiscovery()` method to send data to the `delegate` when the `scanner` receives new advertising data. `handleDiscovery()` has the `scanEntry` argument containing device information and advertising data.  Also in `handleDiscovery()` are the arguments `isNewDev` and `isNewData` which aren't pertinent to DREAM, so they're disregarded.

### Mike validated our understanding of the data with `test_sniffer.py`
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

## Runing the python script
DREAM's python screen needs `redis` and `virtualenv` to run properly.  Here's the setup:

Close the git repo:
```  
git clone...
```  

Install redis: 
```
sudo apt-get install redis-server -y 
```  

Go into the directory where you're going to run the script (in our case `sobun`) since you're about to create an important subdirectory. Install virtualenv and activate it:

```  
sudo pip install virtualenv   
```  
```  
virtualenv venv
```  
```  
source venv/bin/activate   
```  
This should add (venv) to the prompt so it now looks something like:

```  
(venv) pi@sueno:~/DREAMassets/sobun $
```  

Install the requirements for python:

```  
 pip install -r requirements.txt
```  

Congrats! :tada: you're now ready to run the python scrips.  For the primary sniffing script in the `dream` directory, run:

```
 sudo ./venv/bin/python -m dream.sniffer 0 
```
Where `-m dream.sniffer` is python convention and `0` refers to the BLE chip built into the RasPi at `hci0`.  If you want to use a BLE USB dongle, change the value to `1` for `hci1`. By default, the sniffer puts BLE packets into a redis queue called `celery`. 

You can see the size of the queue by opening another terminal. To see the list length (`llen`) of the queue, run:

``` 
redis-cli llen celery 
```

You'll probably want to watch the queue filling with packets so run:

``` 
watch -n0.2 redis-cli llen celery 
```

By default, `watch` runs a command every 2 seconds. Use `-n` to set the time interval of your choosing. 

----------------------

## Setup Soracom

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

_Debug_: If you have trouble SSH'ing into your Hub using `ssh pi@sueno.local` you can use the LAN IP address -- in the example above that's `inet 10.4.8.68`. So you could `ssh pi@10.4.8.68`.  There's a mapping from `sueno.local` to `10.4.8.68` that sometimes breaks, so by going direct to IP address, you can work around the problem.  

Run the following commands to grab and execute Soracom's helper script. This will make Soracom cell the default internet connection on your Hub.

Go to the directory with the soracom file:

```  
cd ~/DREAMassets/soracom
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


----------------------

##Rit's notes
Decouple packects data collection from data publishing

At a high level, we will put BLE packets into a redis queue. We publish the data by popping off the queue and send the data to Google Cloud PubSub.

Edit from OSX using `sshfs`

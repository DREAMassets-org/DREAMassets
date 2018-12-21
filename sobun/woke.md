# December recipe for DREAM project: 
Here's how to build the Hub and Cloud. 

## Steps to build cloud
In Google Cloud Platform (GCP):

* Create a service account with permissions to publish to PubSub and generate a JSON key.  The Hub will use this key.

* In GCP BigQuery, create a dataset (`project_dataset`) and two tables (`project_decimal_values_table` and `project_hex_measurements_table`).  For the tables, under `Schema` select `Edit as text`. 
  * For hex measurements use this schema: `tag_id:STRING,measurements:STRING,hub_id:STRING,timestamp:INTEGER,rssi:INTEGER,hci:INTEGER`
  * For decimal values use this schema: `hub_id:STRING,tag_id:STRING,temperature:FLOAT,x_accel:FLOAT,y_accel:FLOAT,z_accel:FLOAT,rssi:INTEGER,hci:INTEGER,timestamp:INTEGER`


* In GCP PubSub create a topic called `project_hex_measurements_topic` where the Hubs will publish the hexidecimal measurements that they gather. 

* Create code in GCP Source Repository (for your GCP cloud function):
  * Clone the github DREAM repo on your local laptop
  * Check out the `hardening` branch 
  * Create a new branch off of `hardening` called `gcp_project_hex_measurements_branch`
  * Go to the `sobun/dream/drainer/` folder -- this is where the GCP code lives.
  * Edit the `main.py` file so that the `dataset_id` and `table_id` point to your `project_dataset` and `project_hex_measurements_table`.      
  * In GCP Source Repositories create a new repo called `project-gcp-hex-measurements-repo`. Select `Push code from a local Git repository` and follow the GCP instructions.
  * Reload your Source Repo page, select your `gcp_project_hex_measurements_branch` branch, navigate to the `main.py` file you customized and ensure that it points to your BigQuery dataset and table.

* Create your GCP Cloud Function:
  * Name the function `project_gcp_hex_measurements_function`  
  * Trigger the function with `Cloud Pub/Sub` on the topic `creyon_cool_hex_measurements_topic`
  * For `Runtime` select `python 3.7` 
  * For `Source code` select the `Cloud Source repository` and enter `project-gcp-hex-measurements-repo`.
  * For `Branch name` enter your `gcp_project_hex_measurements_branch` branch.
  * For `Directory` enter the `sobun/dream/drainer/` folder.  
  * For `Function to execute` enter `run`
  * Under `Advanced options` be sure to enable `Retry on failure`.
  * Finally, click `Create`. 


## Build `woke` Hub 

### Prepare the Raspberry Pi: 

* Start with clean RasPi with a wifi connection

* Make sure your Pi has the latest software:

```
sudo apt-get update  
```

```
sudo apt-mark hold wolfram-engine
```

```
sudo apt-get upgrade -y
```

* Install packages necessary for this project. Get glib2.0, Google Cloud PubSub, BLE, python daemon, redis and virtualenv: 

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

```
sudo apt-get install wvdial -y
```

***DO NOT install the `NetworkManager` package.*** In previous versions of the DREAM project we used `NetworkManager`, but we discovered that it breaks our cellular connectivity :/ Going forward we're using `wvdial` instead.   
_Note: We still need to add a script to restart PubSub publishing when the cell connectivity resumes. Felix provided some details_

* Install packages for debugging the Pi:

```
sudo apt-get install sqlite -y
```

```
sudo apt-get install time
```


```
sudo apt-get install speedtest-cli
```

```
sudo apt-get install wondershaper
```


* Modify the `/etc/sysctl.conf` by adding a line with `vm.overcommit_memory=1`:

```
sudo pico /etc/sysctl.conf
```

* To keep the logging files to a mininal disk usage, we can set the maxsize to 1M. Modify `/etc/logrotate.conf` by adding this line at the top:

```
sudo pico /etc/logrotate.conf
```
```
maxsize 1M
```

### Set up the files for the DREAM project:
* Change the Hub home directory to have 3 folders: `Desktop`, `secrets`, and `repo`

* In the `secrets/` folder, create an empty placeholder file for the PubSub JSON key:

```
cd secrets
```
```
touch google-credentials.secret.json
```

* In the `repo/` directory, git clone this repo and change the name of the subdirectory from `DREAMassets` to `dream.git`.

```
git clone https://github.com/DREAMassets-org/DREAMassets.git
mv DREAMassets dream.git
```

* Go into the `dream.git/` directory and checkout the `hardening` branch:

```
git checkout hardening
```

* Create the virtual environment from `sobun/`:

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

Deactivate the virtual environment:

```
deactivate
```

* Customize the Hub for your specific project

Make the `config.py` file point to your PubSub topic: 

```
cd repo/dream.git/sobun/dream/
```
```
pico config.py
```
```
GOOGLE_PROJECT_ID = os.environ.get("GOOGLE_PROJECT_ID", "your-gcp-project")
GOOGLE_PUBSUB_TOPIC = os.environ.get("GOOGLE_PUBSUB_TOPIC ", "project_hex_measurements_topic")
```


*  On your laptop, copy the GCP PubSub JSON key you created previously to the `secrets` folder on your `woke` Hub:

```
  scp project-aa11bb00cc22dd44.json pi@woke.local:~/secrets/
```

* Back on your `woke` Hub, go to `secrets/` and copy your unique JSON key into the placeholder file:

```
cp project-aa11bb00cc22dd44.json google-credentials.secret.json
```


* Customize the wifi connection so the Pi no longer connects to the local network and reboot the Pi:

```
sudo pico /etc/wpa_supplicant/wpa_supplicant.conf
```

* Setup the cellular connection:

```
cd ~/repo/dream.git/soracom
```

```
chmod +x setup_air_3G_only.sh
```

```
./setup_air_3G_only.sh
```

Restart the Pi:

```
sudo reboot
```

Plug in the cellular USB dongle with an activated Soracom SIM card. Wait for the blinking light to go solid blue. Log into the Pi again and validate that the Soracom cell connection is working:

```
traceroute fast.com
```

One of the first hops should be through Soracom's server at `eu-central-1.compute.amazonaws.com`. 

Finally, run the `pristine.sh` file to copy the DREAM systemd files so that the Hub runs automatically:

```
cd ~/repo/dream.git/
./pristine.sh
```

Reboot your Pi and 
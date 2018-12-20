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

* Start with clean RasPi

* Change the home directory to have 3 folders: `Desktop`, `secrets`, and `repo`

* In the `secrets/` directory create the JSON key file:

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


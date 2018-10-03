To deploy this cloud function, you must be in the directory that includes the `main.py` which
should be the same directory this README is in.

Then run:

```
gcloud beta functions deploy generate_events_reports --trigger-http --runtime python37 --timeout 120
```

If successful this will give you the URL to trigger the job

You need to pass the bucket, dataset and table with that curl request:
```
curl https://us-central1-dreamassettester.cloudfunctions.net/generate_events_reports?bucket=<bucket>&bq_dataset=<dataset id>&bq_table=<measurements table name>
```  

FOR THE DREAM PROJECT:  
```  
curl https://us-central1-dreamassettester.cloudfunctions.net/generate_events_reports?bucket=<dream_orange_bucket>&bq_dataset=<dream_orange_dataset>&bq_table=<dream_orange_measurements_table>
```  
```  
curl https://us-central1-dreamassettester.cloudfunctions.net/generate_events_reports?bucket=<dream_c5_bucket>&bq_dataset=<dream_c5_dataset>&bq_table=<dream_c5_measurements_table>
```  

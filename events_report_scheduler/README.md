## Scheduler App for to generate our events reports (using the `cloud_functions/generate_events_reports` cloud function)


To deploy this app, 
update `main.py` and set the bucket, project, dataset and table variables to match your project.
You might also check that the URL pattern matches what the one you got when you deployed the
`generate_events_reports` cloud function.

Once those are all up to date you can deploy the app and the scheduler:
```
gcloud app deploy app.yaml
gcloud app deploy cron.yaml 
```

At the end of this, you'll get a link that shows you your scheduled jobs in the Google Console.
You can force run one of the jobs to make sure it's working.


Note:  This code was basically following the recipe laid out here https://medium.com/google-cloud/google-cloud-functions-scheduling-cron-5657c2ae5212
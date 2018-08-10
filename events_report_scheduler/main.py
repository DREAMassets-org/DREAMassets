import webapp2
import urllib2
class GenerateEventsReports(webapp2.RequestHandler):
    def get(self):
        # Before deploying this app, make sure these are set to match your deployed cloud function
        project = "dreamassettester"
        bucket = "dream-assets-orange"
        dataset = "measurements_dataset"
        table = "measurements_table"
        url = "https://us-central1-{project}.cloudfunctions.net/generate_events_reports?bucket={bucket}&bq_dataset={dataset}&bq_table={table}".format(project=project, bucket=bucket, dataset=dataset, table=table)
        print("Fetching url {}".format(url))
        request = urllib2.Request(url, timeout=300 headers={"cronrequest" : "true"})
        contents = urllib2.urlopen(request).read()

app = webapp2.WSGIApplication([
    ('/daily', GenerateEventsReports),
    ], debug=True)

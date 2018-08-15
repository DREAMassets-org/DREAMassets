import imp
import os
import sys
import socket

root_dir = os.path.dirname(os.path.abspath(__file__)) + "/../.."
env = imp.load_source("environment", root_dir + "/secrets/environment.py")

def fetch():
  try:
    settings = {
      'project_id': env.SECRETS["GOOGLE_PROJECT_ID"] or os.environ["GOOGLE_PROJECT_ID"],
      'credentials': env.SECRETS["GOOGLE_CREDENTIALS_JSON_FILE"] or os.environ["GOOGLE_CREDENTIALS_JSON_FILE"],
      'bucket': env.SECRETS["GOOGLE_BUCKET"] or os.environ["GOOGLE_BUCKET"],
      'directory': env.SECRETS["GOOGLE_DIRECTORY"] or os.getenv("GOOGLE_DIRECTORY"),
      'bq_dataset': env.SECRETS["GOOGLE_BQ_DATASET"] or os.getenv("GOOGLE_BQ_DATASET"),
      'bq_table': env.SECRETS["GOOGLE_BQ_TABLE"] or os.getenv("GOOGLE_BQ_TABLE"),
      'host': env.SECRETS.get("HUB_ID", socket.gethostname())
    }
    if not os.path.isfile(settings['credentials']):
      msg = ("The GOOGLE_CREDENTIALS_JSON_FILE %s does not seem to exist."
             "  Please check your installation." % settings['credentials'])
      print >> sys.stderr, msg
      exit(1)
    return settings
  except TypeError:
    print("\n***")
    print("Did you forget to setup your environment variables?")
    print("***\n")
    raise

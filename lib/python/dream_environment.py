import imp
import os
import socket

root_dir = os.path.dirname(os.path.abspath(__file__)) + "/../.."
env = imp.load_source("environment", root_dir + "/secrets/environment.py")

def fetch():
  try:
    return {
      'project_id': env.SECRETS["GOOGLE_PROJECT_ID"] or os.environ["GOOGLE_PROJECT_ID"],
      'credentials': env.SECRETS["GOOGLE_CREDENTIALS_JSON_FILE"] or os.environ["GOOGLE_CREDENTIALS_JSON_FILE"],
      'bucket': env.SECRETS["GOOGLE_BUCKET"] or os.environ["GOOGLE_BUCKET"],
      'directory': env.SECRETS["GOOGLE_DIRECTORY"] or os.getenv("GOOGLE_DIRECTORY"),
      'bq_dataset': env.SECRETS["GOOGLE_BQ_DATASET"] or os.getenv("GOOGLE_BQ_DATASET"),
      'bq_table': env.SECRETS["GOOGLE_BQ_TABLE"] or os.getenv("GOOGLE_BQ_TABLE"),
      'host': socket.gethostname()
    }
  except TypeError:
    print("\n***")
    print("Did you forget to setup your environment variables?")
    print("***\n")
    raise

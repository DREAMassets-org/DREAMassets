# This is an example environment file. All values are bogus. You need to replace them.
# You must replace these bogus values with real values in order for the DREAM project to work.
export GOOGLE_PROJECT_ID=bogus-project-ID
export GOOGLE_BUCKET=bogus-bucket
export GOOGLE_DIRECTORY=bogus-directory
# This environmental file looks for you credentials.json in the /secrets folder to get the key to your Service account in Google Cloud Storage.
export GOOGLE_CREDENTIALS_JSON_FILE="./secrets/credentials.json"

# optionals
export HUB_ID=the-hub-name
export BUNDLE_SIZE=15
export LOG_LEVEL=DEBUG

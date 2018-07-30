# This is an example environment file. All values are bogus. You need to replace them. 
# You must replace these bogus values with real values in order for the DREAM project to work. 
export GOOGLE_PROJECT_ID=bogus-project-ID
export GOOGLE_BUCKET=bogus-bucket
export GOOGLE_DIRECTORY=bogus-directory
# This environmental file looks for you credentials.json in the /secrets folder. 
# You need to remove the credentials.example.json file that we've put there.
export GOOGLE_CREDENTIALS_JSON_FILE="./secrets/credentials.example.json"

# optionals
export BUNDLE_SIZE=15
export LOG_LEVEL=DEBUG



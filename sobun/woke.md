## Steps to build `woke` Hub

1. Start with clean RasPi
1. Change the home directory to have 3 folders: `Desktop`, `secrets`, and `repo`
1. In the `secrets/` directory create the JSON key file:
```
google-credentials.secret.json
```
1. In the `repo/` directory, git clone this repo and change the name of the subdirectory from `DREAMassets` to `dream.git`.
```
git clone https://github.com/DREAMassets-org/DREAMassets.git
mv DREAMassets dream.git
```
1. Go into the `dream.git/` directory and checkout the `hardening` branch:
```
git checkout hardening
```

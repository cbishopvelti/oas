# Oas

## Deploy

```
docker build . -t chrisjbishop155/oas
docker push chrisjbishop155/oas
```

docker run
```
docker run -it -d \
--name oas \
--add-host=host.docker.internal:host-gateway \
-e APP_URL="https://admin.oxfordshireacrosociety.co.uk" \
-e REACT_APP_SERVER_URL="https://server.oxfordshireacrosociety.co.uk" \
-e DB_FILE=/dbs/qslite-dev.db \
-e DOMAIN=.oxfordshireacrosociety.co.uk
-v /Users/chris/playground/oas/dbs:/dbs \
-p 3999:3999 -p 4000:4000 -p 3998:3998 \
chrisjbishop155/oas:latest
```

```
docker run -it -d `
--name oas `
--add-host=host.docker.internal:host-gateway `
-e REACT_APP_ADMIN_URL="https://admin.oxfordshireacrosociety.co.uk" `
-e REACT_APP_SERVER_URL="https://server.oxfordshireacrosociety.co.uk" `
-e REACT_APP_PUBLIC_URL="https://www.oxfordshireacrosociety.co.uk" `
-e DOMAIN=".oxfordshireacrosociety.co.uk" `
-e MIX_ENV=prod `
-e DB_FILE="/dbs/sqlite-prod.db" `
-p 4000:4000 -p 3999:3999 -p 3998:3998 `
-v D:/oas-dbs:/dbs `
chrisjbishop155/oas:latest
```

## Todo


Tokens config

Backup

Icon

Add counts to header
- tokens, token debt
- members
- transactions
- trainings

DEPLOY

Change header title functionality (maybe react-portal)

Export for spreadsheets

Graphs

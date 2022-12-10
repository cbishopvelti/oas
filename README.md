# Oas

## Deploy

```
docker build . -t chrisjbishop155/oas
docker push chrisjbishop155/oas
```
```
docker pull chrisjbishop155/oas
```


docker run -it -d `
--name=oas `
-e DANGEROUSLY_DISABLE_HOST_CHECK=true `
-e REACT_APP_ADMIN_URL="https://admin.oxfordshireacrosociety.co.uk" `
-e REACT_APP_SERVER_URL="https://server.oxfordshireacrosociety.co.uk" `
-e REACT_APP_PUBLIC_URL="https://www.oxfordshireacrosociety.co.uk" `
-e DOMAIN=".oxfordshireacrosociety.co.uk" `
-e DB_FILE=/dbs/sqlite-prod.db `
-e MIX_ENV=prod `
-p 4000:4000 -p 3999:3999 -p 3998:3998 `
-v D:/oas-dbs:/dbs `
-v C:/oas-dbs-backup:/dbs-backup `
chrisjbishop155/oas:latest

docker run -it -d `
--name=oas-staging `
-e DANGEROUSLY_DISABLE_HOST_CHECK=true `
-e REACT_APP_ADMIN_URL="https://admin.staging.oxfordshireacrosociety.co.uk" `
-e REACT_APP_SERVER_URL="https://server.staging.oxfordshireacrosociety.co.uk" `
-e REACT_APP_PUBLIC_URL="https://www.staging.oxfordshireacrosociety.co.uk" `
-e DOMAIN=".staging.oxfordshireacrosociety.co.uk" `
-e DB_FILE=/dbs/sqlite-stage.db `
-e MIX_ENV=stage `
-p 5000:4000 -p 4999:3999 -p 4998:3998 `
-v D:/oas-dbs:/dbs `
-v C:/oas-dbs-staging-backup:/dbs-backup `
chrisjbishop155/oas:latest

Certs
```
certbot certonly --webroot
server.oxfordshireacrosociety.co.uk admin.oxfordshireacrosociety.co.uk www.oxfordshireacrosociety.co.uk
server.staging.oxfordshireacrosociety.co.uk admin.staging.oxfordshireacrosociety.co.uk www.staging.oxfordshireacrosociety.co.uk
C:\Users\chris\nginx-1.23.2\html
C:\Users\chris\nginx-1.23.2\html-staging
```


## Todo

Save success

make analysis use the same filter state

Make prices text pulled from database

Show last transaction

Add warning for manual duplicate transaction.

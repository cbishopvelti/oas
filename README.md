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

~~Sorting again~~

~~Website menu~~

Check website text

~~ Add counts to header ~~
~~ - tokens, token debt~~
~~- trainings~~
~~ - members ~~
~~ - transactions ~~

~~Tokens config~~

~~used_on date~~

Graphs
- Bar chart attendance
Line of tokens
- Line of ballance and liability
- Line income, outgoing, coloured by tags

~~Only send email after last transaction~~

Fix changing import who from invalid to valid, doesn't change the import toggle.

Fix Member filter changing names

Fix Mui warnings on import tags
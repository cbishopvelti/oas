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

Do Import
- Temporaly save import state
- Save tag state

Order of added attendance

Rounding transactions total

Recieved refenence auto fill?

Save success

Add user email error message, is it displayed?


###

If you could send me that when you get a minute.
Have you bought tokens for the jam's you've attended?
It's 5 GBP for 1 token, or 45 for 10. So far you've attended 3 jams.
You've been to 3 jams now, so if you could pay membership (which is to the 31/10/23) of 6 GBP before next jam.
That would be amazing.
Bacs to:
Anne Hedegaard
20-65-18
13072630
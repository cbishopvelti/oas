# Oas

## Deploy

```
docker build . -t chrisjbishop155/oas
docker push chirsjbishop155/oas
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
-p 3999:3999 -p 4000:4000 \
chrisjbishop155/oas:latest
```

```
docker run -it -d `
--name oas `
--add-host=host.docker.internal:host-gateway `
-e APP_URL="https://admin.oxfordshireacrosociety.co.uk" `
-e REACT_APP_SERVER_URL="https://server.oxfordshireacrosociety.co.uk" `
-e DB_FILE="/dbs/sqlite-staging.db"
-v /mnt/d/oas-dbs:/dbs `
chrisjbishop155/oas:latest
```

## Todo

Tags
- blocked mui down

Import and infer transactions from bank statements

Historic data
- Add tokens without transactions
- Add attendances to a "historic trainings" for debt
- Maybe clear all debt / write off
- Attempt to import historic data (hard)


Backup

DEPLOY

Export for spreadsheets

Booking
- gather requirements

Membership
- gather requirements

Track hall bookings
- gather requirements
- look at import from bank statements

Members can see their available tokens
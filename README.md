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

Trainings warning
- if member has run out of non membership attendance.
- if member is running out of tokens.
- if in debt.

Analysis revamp

Delete transaction
- with confirmation
- orphaned membership
- orphaned tokens

add not_transaction field to transactions
- excluded/treated_differently from analysis.

Delete membership (only if no transaction)

add is valid member filter
  - to training member drop down
  - to transactions
  - members list page (think about)


Historic data
- Add tokens without transactions
- Add attendances to a "historic trainings" for debt
- Maybe clear all debt / write off
- Attempt to import historic data (hard)

Analysis, transaction not_transaction

Backup

DEPLOY

Export for spreadsheets

Booking
- gather requirements

Membership
- gather requirements

Track bookings
- gather requirements
- look at import from bank statements

Members can see their available tokens

Filter transactions

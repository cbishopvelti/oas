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
-e APP_URL="https://admin.oxfordshireacrosociety.co.uk" `
-e REACT_APP_SERVER_URL="https://server.oxfordshireacrosociety.co.uk" `
-e DB_FILE="/dbs/sqlite-staging.db"
-v /mnt/d/oas-dbs:/dbs `
chrisjbishop155/oas:latest
```

## Todo


Add sending email
- if in debt.

Delete transaction
- with confirmation
- orphaned membership
- orphaned tokens

add not_transaction field to transactions
- excluded/treated_differently from analysis.

Import and infer transactions from bank statements

Add membership list to:
- Members
- MembershipPeriod

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

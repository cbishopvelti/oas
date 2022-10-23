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
-e APP_URL="https://admin.oxfordshireacrosociety.co.uk"
-e REACT_APP_SERVER_URL="https://server.oxfordshireacrosociety.co.uk"
-v /mnt/d/oas-dbs:/dbs \
chirsjbishop155/oas:latest
```

```
docker run -it -d `
--name oas `
--add-host=host.docker.internal:host-gateway `
-e APP_URL="https://admin.oxfordshireacrosociety.co.uk" `
-e REACT_APP_SERVER_URL="https://server.oxfordshireacrosociety.co.uk" `
-e DB_FILE="/dbs/sqlite-staging.db"
-v /mnt/d/oas-dbs:/dbs `
chirsjbishop155/oas:latest
```

## Todo

Import and infer transactions from bank statements

Backup

Booking

Delete attendance
Delete trainings

Add membership

Track hall bookings

Hosting

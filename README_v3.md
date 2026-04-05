```
docker build . \
--build-arg MIX_ENV=v2_prod \
-f Dockerfile_v3 -t chrisjbishop155/oas:v3_prod

docker push chrisjbishop155/oas:v3_prod
```

### Ubuntu

```
--restart unless-stopped \

docker stop oas; docker rm oas; \
docker run -it -d \
--name=oas \
-e DANGEROUSLY_DISABLE_HOST_CHECK=true \
-e REACT_APP_ADMIN_URL="https://admin.oxfordshireacrosociety.co.uk" \
-e REACT_APP_SERVER_URL="https://server.oxfordshireacrosociety.co.uk" \
-e REACT_APP_PUBLIC_URL="https://www.oxfordshireacrosociety.co.uk" \
-e DOMAIN=".oxfordshireacrosociety.co.uk" \
-e DB_FILE=/dbs/sqlite-prod.db \
-e MIX_ENV=v2_prod \
-p 80:80 -p 443:443 \
-v /mnt/cb33437a-ff3b-43a5-ac74-23fcfb95a022/root/oas-dbs:/dbs \
-v /oas-dbs-backup:/oas-dbs-backup \
-v /mnt/cb33437a-ff3b-43a5-ac74-23fcfb95a022/root/gocardless_backup:/gocardless_backup \
--add-host host.docker.internal:host-gateway \
chrisjbishop155/oas:v3_prod
```


### STAGING
```
docker build . \
--build-arg MIX_ENV=v3_staging \
--build-arg SUBDOMAIN=.staging \
-f Dockerfile_v3 -t chrisjbishop155/oas:v3_staging
```

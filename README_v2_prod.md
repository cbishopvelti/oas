

```
docker build . \
--build-arg MIX_ENV=v2_prod \
-f Dockerfile_v2 -t chrisjbishop155/oas:v2_prod

docker push chrisjbishop155/oas:v2_prod
```

```
docker pull chrisjbishop155/oas:v2_prod;

docker stop oas; docker rm oas; \
docker run -it -d \
--restart unless-stopped \
--name=oas \
-e DANGEROUSLY_DISABLE_HOST_CHECK=true \
-e REACT_APP_ADMIN_URL="https://admin.oxfordshireacrosociety.co.uk" \
-e REACT_APP_SERVER_URL="https://server.oxfordshireacrosociety.co.uk" \
-e REACT_APP_PUBLIC_URL="https://www.oxfordshireacrosociety.co.uk" \
-e DOMAIN=".oxfordshireacrosociety.co.uk" \
-e DB_FILE=/dbs/sqlite-prod.db \
-e MIX_ENV=v2_prod \
-p 80:80 -p 443:443 \
-v /oas-dbs:/dbs \
-v /mnt/disk2/oas-dbs-backup:/oas-dbs-backup \
-v /gocardless_backup:/gocardless_backup \
chrisjbishop155/oas:v2_prod
```

```
docker exec -it oas /bin/bash
cp /app/nginx/v2_nginx.conf /etc/nginx/nginx.conf && certbot --nginx
nginx -s stop
nginx
```

```
gcloud compute ssh --project oxfordshire-acro --zone europe-west2-c instance-template-20241125-20241125-110930
gcloud compute scp --project oxfordshire-acro --zone europe-west2-c --recurse `
C:\Users\chris\Downloads\to_scp\ instance-template-20241125-20241125-110930:/mnt/disks/data/

gcloud compute scp --project oxfordshire-acro --zone europe-west2-b \
instance-3:/mnt/disks/data/{sqlite-prod.db,sqlite-prod.db-shm,sqlite-prod.db-wal} \
/Users/chris/playground/oas/dbs/2025-03/
```

```
gcloud compute scp --project oxfordshire-acro --zone europe-west2-a \
/Users/chris/playground/oas/dbs/2025-03/{sqlite-dev.db,sqlite-dev.db-shm,sqlite-dev.db-wal} \
instance-4-dev:/mnt/disks/data/

```

#### tmux
```
tmux attach -t server
tmux detach CTRL + b then d
```
tmux scroll mode:
```
ctrl + b then [
q
```

```
certbot renew
```


#### gmail forwarding
google app password ***REMOVED***

##### Works:
:gen_smtp_client.open([port: 587, relay: "smtp.gmail.com", username: "chrisjbishop155@gmail.com", password: "***REMOVED***", auth: :always, sls: :always, ssl: false, tls: :always, tls_options: [verify: :verify_none]])

#### Ubuntu

docker run -it -d \
--restart unless-stopped \
--name=oas \
-e DANGEROUSLY_DISABLE_HOST_CHECK=true \
-e REACT_APP_ADMIN_URL="https://admin.oxfordshireacrosociety.co.uk" \
-e REACT_APP_SERVER_URL="https://server.oxfordshireacrosociety.co.uk" \
-e REACT_APP_PUBLIC_URL="https://www.oxfordshireacrosociety.co.uk" \
-e DOMAIN=".oxfordshireacrosociety.co.uk" \
-e DB_FILE=/dbs/sqlite-prod.db \
-e MIX_ENV=v2_prod \
-p 80:80 -p 443:443 \
-v /media/chris/fedora/root/oas-dbs:/dbs \
-v /oas-dbs-backup:/oas-dbs-backup \
-v /media/chris/fedora/root/gocardless_backup:/gocardless_backup \
chrisjbishop155/oas:v2_prod

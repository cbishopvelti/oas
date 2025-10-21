

```
docker build . --build-arg MIX_ENV=dev-docker \
--build-arg SUBDOMAIN=dev \
-f Dockerfile_v2 -t chrisjbishop155/oas:dev

docker push chrisjbishop155/oas:dev
```

```
docker pull chrisjbishop155/oas:dev;

docker stop oas-dev; docker rm oas-dev; \
docker run -it -d \
--name=oas-dev \
-e DANGEROUSLY_DISABLE_HOST_CHECK=true \
-e REACT_APP_ADMIN_URL="https://admin.dev.oxfordshireacrosociety.co.uk" \
-e REACT_APP_SERVER_URL="https://server.dev.oxfordshireacrosociety.co.uk" \
-e REACT_APP_PUBLIC_URL="https://www.dev.oxfordshireacrosociety.co.uk" \
-e DOMAIN=".dev.oxfordshireacrosociety.co.uk" \
-e DB_FILE=/dbs/sqlite-prod-2025-09-13c.db \
-e MIX_ENV=dev-docker \
-p 80:80 -p 443:443 \
-v /home/chris/playground/oas/dbs:/dbs \
chrisjbishop155/oas:dev
```

https://cloud.google.com/compute/docs/disks/format-mount-disk-linux

```
docker exec -it oas-dev /bin/bash
cp /app/nginx/v2_dev_nginx.conf /etc/nginx/nginx.conf
certbot --nginx
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

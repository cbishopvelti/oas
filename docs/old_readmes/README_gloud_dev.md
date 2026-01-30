

```
docker build . --build-arg MIX_ENV=gcloud_dev \
--build-arg SUBDOMAIN=gcloud-dev \
-f Dockerfile_gcloud -t chrisjbishop155/oas:dev

docker push chrisjbishop155/oas:dev
```

```
docker pull chrisjbishop155/oas:dev;

docker stop oas; docker rm oas; \
docker run -it -d \
--name=oas \
-e DANGEROUSLY_DISABLE_HOST_CHECK=true \
-e REACT_APP_ADMIN_URL="https://admin.gcloud-dev.oxfordshireacrosociety.co.uk" \
-e REACT_APP_SERVER_URL="https://server.gcloud-dev.oxfordshireacrosociety.co.uk" \
-e REACT_APP_PUBLIC_URL="https://www.gcloud-dev.oxfordshireacrosociety.co.uk" \
-e DOMAIN=".gcloud-dev.oxfordshireacrosociety.co.uk" \
-e DB_FILE=/dbs/sqlite-dev.db \
-e MIX_ENV=gcloud_dev \
-p 80:80 -p 443:443 \
-v /mnt/disks/data:/dbs \
chrisjbishop155/oas:dev
```

https://cloud.google.com/compute/docs/disks/format-mount-disk-linux

```
docker exec -it oas /bin/bash
cp /app/nginx/gcloud_dev_pre_nginx.conf /etc/nginx/nginx.conf
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

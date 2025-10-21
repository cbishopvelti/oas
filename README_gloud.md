


```
docker pull chrisjbishop155/oas:latest;

docker stop oas; docker rm oas; \
docker run -it -d \
--name=oas \
-e DANGEROUSLY_DISABLE_HOST_CHECK=true \
-e REACT_APP_ADMIN_URL="https://admin.gcloud.oxfordshireacrosociety.co.uk" \
-e REACT_APP_SERVER_URL="https://server.gcloud.oxfordshireacrosociety.co.uk" \
-e REACT_APP_PUBLIC_URL="https://www.gcloud.oxfordshireacrosociety.co.uk" \
-e DOMAIN=".gcloud.oxfordshireacrosociety.co.uk" \
-e DB_FILE=/dbs/sqlite-prod.db \
-e MIX_ENV=gcloud \
-p 80:80 -p 443:443 \
-v /mnt/disks/data:/dbs \
chrisjbishop155/oas:latest
```


```
cp /app/nginx/gcloud_pre_nginx.conf /etc/nginx/nginx.conf
```

```
certbot --nginx
```

```
gcloud compute ssh --project oxfordshire-acro --zone europe-west2-c instance-template-20241125-20241125-110930
gcloud compute scp --project oxfordshire-acro --zone europe-west2-c --recurse `
C:\Users\chris\Downloads\to_scp\ instance-template-20241125-20241125-110930:/mnt/disks/data/

```
### Attempt 2

Create instance checklist
- Contair optimized os
- 20GB storage
- create storage from existing snapshot
- enable http and https traffic

Mounting the disk
https://cloud.google.com/compute/docs/disks/format-mount-disk-linux

sudo mount -o discard,defaults /dev/disk/by-id/google-disk-3 /mnt/disks/data


```
docker stop oas; docker rm oas; \
docker run -it -d \
--name=oas \
-e DANGEROUSLY_DISABLE_HOST_CHECK=true \
-e REACT_APP_ADMIN_URL="https://admin.gcloud.oxfordshireacrosociety.co.uk" \
-e REACT_APP_SERVER_URL="https://server.gcloud.oxfordshireacrosociety.co.uk" \
-e REACT_APP_PUBLIC_URL="https://www.gcloud.oxfordshireacrosociety.co.uk" \
-e DOMAIN=".gcloud.oxfordshireacrosociety.co.uk" \
-e DB_FILE=/dbs/sqlite-prod.db \
-e MIX_ENV=gcloud \
-p 80:80 -p 443:443 \
-v /mnt/disks/data:/dbs \
--entrypoint /bin/bash \
chrisjbishop155/oas:latest


gcloud compute scp --project oxfordshire-acro --zone europe-west2-b \
instance-3:/mnt/disks/data/{sqlite-prod.db,sqlite-prod.db-shm,sqlite-prod.db-wal} \
/Users/chris/playground/oas/dbs/2025-03/
```

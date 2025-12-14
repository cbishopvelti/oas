
docker build . \
--build-arg MIX_ENV=v3_dev \
-f Dockerfile_v3_dev -t chrisjbishop155/oas:v3_dev

```
docker stop oas; docker rm oas; \
docker run -it -d \
--name=oas \
-e DANGEROUSLY_DISABLE_HOST_CHECK=true \
-e REACT_APP_ADMIN_URL="http://localhost:3999" \
-e REACT_APP_SERVER_URL="http://localhost:4000" \
-e REACT_APP_PUBLIC_URL="http://localhost:3998" \
-e DOMAIN="localhost" \
-e MIX_ENV=v3_dev \
-p 4000:4000 -p 3998:3999 -p 3999:3999 \
-v ./clustering/node1/oas-dbs-backup:/oas-dbs-backup \
-v ./clustering/node1/gocardless_backup:/gocardless_backup \
-v ./:/app \
--add-host host.docker.internal:host-gateway \
chrisjbishop155/oas:v3_dev
```

```bash
docker compose -f clustering/docker-compose.yaml up -d

iex --sname n1@phoenix-n1 -S mix phx.server
```

```bash tmux
respawn-pane -k /bin/bash
```


### TODO:

Backups
libcluster
virtual ip

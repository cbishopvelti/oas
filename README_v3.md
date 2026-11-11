## Build

The image is built per environment with the `MIX_ENV` build arg. The build also
runs `mix esbuild default --minify` to bundle the Phoenix JS/CSS (the esbuild
watcher is off outside dev), so keep that step if you edit the Dockerfile.

`SUBDOMAIN` only sets the URLs baked into the two React apps (`REACT_APP_*`).
The cookie domain (`DOMAIN`) is no longer baked into the image: pass it at run
time, as below.

```
docker build . \
--build-arg MIX_ENV=v2_prod \
-f Dockerfile_v3 -t chrisjbishop155/oas:v3_prod

docker push chrisjbishop155/oas:v3_prod
```

## Run

### Environment overrides

Any setting in [.env.example](./.env.example) can be overridden at start-up
without rebuilding. Copy it to a file outside git (e.g. `/etc/oas/society.env`),
uncomment the lines you need, and add `--env-file /etc/oas/society.env` to the
`docker run` command. Variables you leave unset keep the value from the config
file the image was built with.

Things to get right:

- `ADMIN_URL` and `PUBLIC_URL` must match the URLs the browser actually uses,
  exactly, scheme included (`https://`, and the port if it is not the default).
  The server only accepts browser (CORS) and socket requests from those two and
  its own host (`PHX_HOST`), so a mismatch shows up as blocked requests.
- `ALLOW_ANY_ORIGIN=true` turns that check off. It is an escape hatch for
  debugging; don't leave it on.
- `DOMAIN` is the cookie domain shared by the server, admin and www hosts, with
  a leading dot. Always pass it, since the image no longer sets it.
- A second society running from the prod image must set at least
  `SECRET_KEY_BASE`, `DB_FILE`, `PHX_HOST`, `DOMAIN`, `ADMIN_URL`, `PUBLIC_URL`
  and `MAIL_FROM_ADDRESS`, or it inherits Oxfordshire's values.

### Ubuntu

```
--restart unless-stopped \

docker stop oas; docker rm oas; \
docker run -it -d \
--name=oas \
`# optional: --env-file /etc/oas/society.env` \
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

The staging image no longer bakes in `DOMAIN` either, so pass
`-e DOMAIN=".staging.oxfordshireacrosociety.co.uk"` (or put it in the env file)
when you run it.

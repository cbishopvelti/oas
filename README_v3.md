## Build

The image is built per environment with the `MIX_ENV` build arg. The build also
runs `mix esbuild default --minify` to bundle the Phoenix JS/CSS (the esbuild
watcher is off outside dev), so keep that step if you edit the Dockerfile.

No URLs or domains are baked into the image, so one image serves prod, staging
and any other society. The two React apps fetch their URLs from `/api/config.js`
at run time, and the server reads `ADMIN_URL`, `PUBLIC_URL` and `DOMAIN` at
start-up. Pass them when you run the container, as below. (The old
`SUBDOMAIN` build arg is gone.)

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

- `ADMIN_URL` and `PUBLIC_URL` must be passed at run time, since the image no
  longer sets them. The old names `REACT_APP_ADMIN_URL` and
  `REACT_APP_PUBLIC_URL` still work (the gcloud configs read them), but
  `ADMIN_URL`/`PUBLIC_URL` win if both are set. If neither is passed, the
  value in the config file the image was built with is used (Oxfordshire's prod
  URLs in the gcloud configs), which is wrong for staging or another society.
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

### Backups

Each backup is written uncompressed to the `backup_database` path (e.g.
`/oas-dbs-backup`). If a backup recipient is set in Config, the same database
is also emailed to them gzipped, as `<society>-<time>.db.gz`.

To restore from the emailed copy, unzip it and use the `.db` file as `DB_FILE`:

```
gunzip <society>-<time>.db.gz
sqlite3 <society>-<time>.db "SELECT * FROM config_config"   # optional sanity check
```

If the email fails to send, the error is logged and a warning shows at the top
of the admin site until a later backup email goes through. The file on disk is
written either way.

### Ubuntu

```
--restart unless-stopped \

docker stop oas; docker rm oas; \
docker run -it -d \
--name=oas \
`# optional: --env-file /etc/oas/society.env` \
-e DANGEROUSLY_DISABLE_HOST_CHECK=true \
-e ADMIN_URL="https://admin.oxfordshireacrosociety.co.uk" \
-e PUBLIC_URL="https://www.oxfordshireacrosociety.co.uk" \
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
-f Dockerfile_v3 -t chrisjbishop155/oas:v3_staging
```

The staging image no longer bakes in any URL or domain, so pass them (or put
them in the env file) when you run it:

```
-e ADMIN_URL="https://admin.staging.oxfordshireacrosociety.co.uk" \
-e PUBLIC_URL="https://www.staging.oxfordshireacrosociety.co.uk" \
-e DOMAIN=".staging.oxfordshireacrosociety.co.uk" \
```

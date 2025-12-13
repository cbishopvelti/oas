```
docker run -d \
  --name oas-postgres \
  -e POSTGRES_PASSWORD=pd6k \
  -v ./dbs/postgres:/var/lib/postgresql \
  -p 5432:5432 \
  postgres
```

```
pgloader ~/oas-dev-dbs/oas-2025-12-03T20_40_04.838455Z.db postgresql://postgres:pd6k@localhost:5432/oas
pgloader oas.load
```

```
docker run --rm -d --name yugabyte01 --hostname yugabyte01 \
    -p 7001:7000 -p 9000:9000 -p 15433:15433 -p 5433:5433 -p 9042:9042 \
    -v ./dbs/yb_data:/home/yugabyte/yb_data \
    yugabytedb/yugabyte:2025.2.0.0-b131 bin/yugabyted start \
    --base_dir=/home/yugabyte/yb_data \
    --background=false \
    --tserver_flags "enable_ysql_conn_mgr=true"
```
```json
  {
    "version": 1,
    "replicationInfo": {
      "liveReplicas": {
        "numReplicas": 1,
        "placementBlocks": [
          {
            "cloudInfo": {
              "placementCloud": "cloud1",
              "placementRegion": "datacenter1",
              "placementZone": "rack1"
            },
            "minNumReplicas": 1
          }
        ],
        "placementUuid": "YTA2YWZhNWYtMzY5OC00YzAwLWE5MTUtMjAyNjk1NzUyMDE1"
      }
    },
    "clusterUuid": "d01ba671-cfea-413b-8f25-cd3e7a58f970",
    "universeUuid": "61ca5ed3-3c7c-40d9-ad26-f2e4eff9e46c"
  }
```


todo:

fresh migration runs
Backup
Setup yugabyteDB

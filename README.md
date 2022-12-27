# Oas

## Deploy

```
docker build . -t chrisjbishop155/oas
docker push chrisjbishop155/oas
```
```
docker pull chrisjbishop155/oas
```

docker stop oas; docker rm oas; `
docker run -it -d `
--name=oas `
-e DANGEROUSLY_DISABLE_HOST_CHECK=true `
-e REACT_APP_ADMIN_URL="https://admin.oxfordshireacrosociety.co.uk" `
-e REACT_APP_SERVER_URL="https://server.oxfordshireacrosociety.co.uk" `
-e REACT_APP_PUBLIC_URL="https://www.oxfordshireacrosociety.co.uk" `
-e DOMAIN=".oxfordshireacrosociety.co.uk" `
-e DB_FILE=/dbs/sqlite-prod.db `
-e MIX_ENV=prod `
-p 4000:4000 -p 3999:3999 -p 3998:3998 `
-v D:/oas-dbs:/dbs `
-v C:/oas-dbs-backup:/dbs-backup `
chrisjbishop155/oas:latest

docker stop oas-staging; docker rm oas-staging; `
docker run -it -d `
--name=oas-staging `
-e DANGEROUSLY_DISABLE_HOST_CHECK=true `
-e REACT_APP_ADMIN_URL="https://admin.staging.oxfordshireacrosociety.co.uk" `
-e REACT_APP_PUBLIC_URL="https://www.staging.oxfordshireacrosociety.co.uk" `
-e REACT_APP_SERVER_URL="https://server.staging.oxfordshireacrosociety.co.uk" `
-e REACT_APP_PUBLIC_URL="https://www.staging.oxfordshireacrosociety.co.uk" `
-e DOMAIN=".staging.oxfordshireacrosociety.co.uk" `
-e DB_FILE=/dbs/sqlite-stage.db `
-e MIX_ENV=stage `
-p 5000:4000 -p 4999:3999 -p 4998:3998 `
-v D:/oas-dbs:/dbs `
-v C:/oas-dbs-staging-backup:/dbs-backup `
chrisjbishop155/oas:booking

Certs
```
certbot certonly --webroot
server.oxfordshireacrosociety.co.uk admin.oxfordshireacrosociety.co.uk www.oxfordshireacrosociety.co.uk
server.staging.oxfordshireacrosociety.co.uk admin.staging.oxfordshireacrosociety.co.uk www.staging.oxfordshireacrosociety.co.uk
C:\Users\chris\nginx-1.23.2\html
C:\Users\chris\nginx-1.23.2\html-staging
```


## Todo

Save success

~~ make analysis use the same filter state ~~

~~ Make prices text pulled from database ~~

~~ Add warning for manual duplicate transaction. ~~

~~Login button~~

~~ Public used on -> Training date ~~

public tokens remaining api return membership status.

curl 'https://www.oxfordshireacrosociety.co.uk/api/graphql' \
  -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36' \
  -H 'accept: */*' \
  -H 'content-type: application/json' \
  --data-raw $'{"variables":{"email":"ben@britishacrobatics.org"},"query":"query ($email: String\u0021) {\\n  public_outstanding_attendance(email: $email) {\\n    id\\n    training_where {\\n      name\\n      __typename\\n    }\\n    when\\n    __typename\\n  }\\n  public_bacs(email: $email)\\n  public_tokens(email: $email) {\\n    id\\n    value\\n    expires_on\\n    used_on\\n    member {\\n      email\\n      name\\n      __typename\\n    }\\n    tr_member {\\n      email\\n      name\\n      __typename\\n    }\\n    training_date\\n    __typename\\n  }\\n  public_config_tokens {\\n    last_transaction_when\\n    token_expiry_days\\n    tokens {\\n      quantity\\n      value\\n      __typename\\n    }\\n    __typename\\n  }\\n}"}' \
  --compressed

curl 'https://server.oxfordshireacrosociety.co.uk/api/graphql' \
  -H 'accept: application/json' \
  -H 'content-type: application/json' \
  --data-raw '{"query":"query {\n  publicMember (email:\"chrisjbishop155@hotmail.com\") {\n    memberStatus\n  }\n}","variables":null}' \
  --compressed

curl 'chrome-extension://fmkadmapgofadopljbjfkapdkoienihi/build/react_devtools_backend.js' \
  -H 'Referer;' \
  -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36' \
  --compressed ;

curl 'https://server.oxfordshireacrosociety.co.uk/api/graphql' \
  -H 'accept: application/json' \
  -H 'content-type: application/json' \
  --data-raw $'{"query":"query ($email:String\u0021) {\\n  publicMember (email:$email) {\\n    memberStatus\\n  }\\n}","variables":{"email":"chrisjbishop155@hotmail.com"}}' \
  --compressed

Make emails optional.
- Registration form merge

## Add tokens

%Oas.Tokens.Token{
  member_id: 29,
  expires_on: Date.add(Date.utc_today(), 365),
  value: 4.5
} |> Oas.Repo.insert()
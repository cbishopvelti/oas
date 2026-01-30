

## Deploy

```
docker build . -t chrisjbishop155/oas
docker push chrisjbishop155/oas
```
```
docker pull chrisjbishop155/oas
```
```
docker stop oas-sales-demo; docker rm oas-sales-demo; `
docker run -it -d `
--name=oas-sales-demo `
-e DANGEROUSLY_DISABLE_HOST_CHECK=true `
-e REACT_APP_ADMIN_URL="https://admin.demo.societybishop.co.uk" `
-e REACT_APP_SERVER_URL="https://server.demo.societybishop.co.uk" `
-e DOMAIN=".demo.societybishop.co.uk" `
-e MIX_ENV=demo `
-p 5200:4000 -p 5199:3999 `
chrisjbishop155/oas:latest
```
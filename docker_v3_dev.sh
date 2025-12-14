#!/bin/sh

tmux new-session -d -s server 'mix ecto.migrate && iex --sname $SNAME -S mix phx.server; /bin/bash'
tmux new-session -d -s admin 'cd /app/oas-web && npm run start'
tmux new-session -d -s public 'cd /app/oas-web-public && npm run start'

# cp /app/nginx/gcloud_pre_nginx.conf /etc/nginx/nginx.conf
# nginx

tail -f /dev/null

#!/bin/sh

tmux new-session -d -s server 'mix ecto.migrate --no-compile && iex -S mix phx.server --no-compile'

cp /app/nginx/traefik_nginx.conf /etc/nginx/nginx.conf
nginx

/bin/bash

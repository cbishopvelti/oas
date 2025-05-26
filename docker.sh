#!/bin/sh

tmux new-session -d -s server 'mix local.rebar --force && mix ecto.migrate && iex -S mix phx.server --no-compile'
# tmux new-session -d -s server 'iex -S mix phx.server --no-compile'

cd ./oas-web
tmux new-session -d -s admin 'npm install && npm run start'
cd ../

cd ./oas-web-public
tmux new-session -d -s public 'npm install && npm run start'
cd ../

# tmux new-session -d -s nginx 'nginx'
nginx

/bin/bash

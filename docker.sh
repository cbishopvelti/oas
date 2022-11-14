#!/bin/sh

tmux new-session -d -s server 'mix ecto.migrate --force && iex -S mix phx.server --force'

cd ./oas-web
tmux new-session -d -s admin 'npm install && npm run start'
cd ../

cd ./oas-web-public
tmux new-session -d -s public 'npm install && npm run start'
cd ../

/bin/bash

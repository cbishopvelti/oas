#!/bin/sh
tmux new-session -d -s server 'mix ecto.migrate && iex -S mix phx.server'

cd ./oas-web
tmux new-session -d -s admin 'npm install && npm run start'
cd ../

cd ./oas-web-public
tmux new-session -d -s public 'npm install && npm run start'
cd ../

/bin/bash

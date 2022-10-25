#!/bin/sh
mix ecto.migrate
tmux new-session -d -s server 'iex -S mix phx.server'

cd ./oas-web
tmux new-session -d -s admin 'npm run start'
cd ../

/bin/bash

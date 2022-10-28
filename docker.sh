#!/bin/sh
tmux new-session -d -s server 'mix ecto.migrate && iex -S mix phx.server'

cd ./oas-web
tmux new-session -d -s admin 'npm install && npm run start'
cd ../

/bin/bash

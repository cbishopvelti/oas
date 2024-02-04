# docker build . -t chrisjbishop155/oas:latest
# docker push chrisjbishop155/oas:latest

from elixir:1.14.1

# Node
# RUN curl -sL https://deb.nodesource.com/setup_18.x | bash -
RUN curl -L https://deb.nodesource.com/nsolid_setup_deb.sh | bash -s -- 18
RUN apt-get update
RUN apt-get install -y vim htop
RUN apt-get install -y nodejs
RUN apt-get install -y tmux
RUN apt-get install -y inotify-tools

WORKDIR /app/oas-web
# RUN npm install

WORKDIR /app
COPY . .
RUN mix local.hex --force
RUN mix deps.get --force
RUN mix local.rebar --force
RUN mix compile
ENV ELIXIR_ERL_OPTIONS="-kernel shell_history enabled"



VOLUME [ "/dbs", "/dbs-backup" ]

# CMD ["iex"]
# CMD ["sleep", "86400"]
# CMD ["iex", "-S", "mix"]
ENTRYPOINT [ "./docker.sh" ]
# CMD /bin/bash tmux new-session -d -s server 'iex -S mix phx.server'
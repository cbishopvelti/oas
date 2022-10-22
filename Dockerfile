# docker build . -t registry.hub.docker.com/chrisjbishop155/oas:latest
# docker push registry.hub.docker.com/chrisjbishop155/oas:latest

from elixir:1.14

# Node
RUN curl -sL https://deb.nodesource.com/setup_18.x | bash -
RUN apt-get update
RUN apt-get install -y vim htop
RUN apt-get install -y nodejs
RUN apt-get install -y tmux

WORKDIR /app
COPY . .
RUN mix local.hex --force
RUN mix deps.get --force
RUN mix compile
ENV ELIXIR_ERL_OPTIONS="-kernel shell_history enabled"

WORKDIR /app/oas-web
RUN npm install


VOLUME [ "/dbs" ]

# CMD ["iex"]
# CMD ["sleep", "86400"]
# CMD ["iex", "-S", "mix"]
CMD ["/bin/bash"]
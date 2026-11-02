# docker build . -t chrisjbishop155/oas:latest
# docker push chrisjbishop155/oas:latest

FROM elixir:1.14.1

RUN apt-get update

# Certbot
RUN apt-get install -y python3 python3-venv libaugeas0
RUN python3 -m venv /opt/certbot/
RUN /opt/certbot/bin/pip install --upgrade pip
RUN /opt/certbot/bin/pip install certbot certbot-nginx
RUN ln -s /opt/certbot/bin/certbot /usr/bin/certbot

# Node
# RUN curl -sL https://deb.nodesource.com/setup_18.x | bash -
RUN curl -L https://deb.nodesource.com/nsolid_setup_deb.sh | bash -s -- 18

RUN apt-get install -y vim htop
RUN apt-get install -y nodejs
RUN apt-get install -y tmux
RUN apt-get install -y inotify-tools
RUN apt-get install -y nginx

WORKDIR /app/oas-web
# RUN npm install

WORKDIR /app
COPY . .
RUN mix local.hex --force
RUN mix deps.get --force
RUN mix local.rebar --force
ENV MIX_ENV=gcloud
RUN mix compile
ENV ELIXIR_ERL_OPTIONS="-kernel shell_history enabled"

# RUN cp ./nginx/gcloud_nginx.conf /etc/nginx/nginx.conf

VOLUME [ "/dbs", "/dbs-backup" ]

# CMD ["iex"]
# CMD ["sleep", "86400"]
# CMD ["iex", "-S", "mix"]
ENTRYPOINT [ "./docker.sh" ]
# CMD /bin/bash tmux new-session -d -s server 'iex -S mix phx.server'

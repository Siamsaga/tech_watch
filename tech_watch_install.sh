#!/bin/bash

set -e

DOMAIN="siamsaga.fr"
EMAIL="contact@siamsaga.fr"

POSTGRES_DB="tech_watch_infra"
POSTGRES_USER="tech_watch"
POSTGRES_PASSWORD=$(openssl rand -base64 18)

INSTALL_DIR="/opt/tech_watch"

echo "===== Mise à jour système ====="

apt update
apt upgrade -y

echo "===== Installation dépendances ====="

apt install -y \
curl \
git \
vim \
ufw \
openssl \
ca-certificates \
gnupg \
lsb-release

echo "===== Installation Docker ====="

curl -fsSL https://get.docker.com | sh

systemctl enable docker
systemctl start docker

echo "===== Firewall ====="

ufw allow 22
ufw allow 80
ufw allow 443

ufw --force enable

echo "===== Arborescence ====="

mkdir -p $INSTALL_DIR

cd $INSTALL_DIR

mkdir -p \
postgres \
freshrss \
n8n \
public \
website \
letsencrypt

echo "===== .env ====="

cat > .env << EOF
DOMAIN=$DOMAIN

ACME_EMAIL=$EMAIL

POSTGRES_DB=$POSTGRES_DB
POSTGRES_USER=$POSTGRES_USER
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
EOF

echo "===== Docker Compose ====="

cat > docker-compose.yml << 'EOF'
services:

  postgres:
    image: postgres:16

    restart: unless-stopped

    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}

    volumes:
      - ./postgres:/var/lib/postgresql/data

  freshrss:

    image: freshrss/freshrss

    restart: unless-stopped

    labels:
      - traefik.enable=true
      - traefik.http.routers.rss.rule=Host(`rss.${DOMAIN}`)
      - traefik.http.routers.rss.tls.certresolver=le

    volumes:
      - ./freshrss:/var/www/FreshRSS/data

  n8n:

    image: docker.n8n.io/n8nio/n8n

    restart: unless-stopped

    environment:
      DB_TYPE: postgresdb
      DB_POSTGRESDB_HOST: postgres
      DB_POSTGRESDB_DATABASE: ${POSTGRES_DB}
      DB_POSTGRESDB_USER: ${POSTGRES_USER}
      DB_POSTGRESDB_PASSWORD: ${POSTGRES_PASSWORD}

    labels:
      - traefik.enable=true
      - traefik.http.routers.n8n.rule=Host(`n8n.${DOMAIN}`)
      - traefik.http.routers.n8n.tls.certresolver=le

    depends_on:
      - postgres

    volumes:
      - ./n8n:/home/node/.n8n

  portainer:

    image: portainer/portainer-ce

    restart: unless-stopped

    command: -H unix:///var/run/docker.sock

    labels:
      - traefik.enable=true

      - traefik.http.routers.portainer.rule=Host(`portainer.${DOMAIN}`)
      - traefik.http.routers.portainer.entrypoints=websecure
      - traefik.http.routers.portainer.tls=true
      - traefik.http.routers.portainer.tls.certresolver=le

    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data

  hugo:

    image: nginx:alpine

    restart: unless-stopped

    labels:
      - traefik.enable=true
      - traefik.http.routers.site.rule=Host(`watch.${DOMAIN}`)
      - traefik.http.routers.site.tls.certresolver=le

    volumes:
      - ./public:/usr/share/nginx/html

  traefik:

    image: traefik:v3

    restart: unless-stopped

    command:
      - --api.dashboard=true
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --certificatesresolvers.le.acme.email=${ACME_EMAIL}
      - --certificatesresolvers.le.acme.storage=/letsencrypt/acme.json
      - --certificatesresolvers.le.acme.httpchallenge=true
      - --certificatesresolvers.le.acme.httpchallenge.entrypoint=web

    ports:
      - "80:80"
      - "443:443"

    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./letsencrypt:/letsencrypt

volumes:

  portainer_data:
EOF

touch letsencrypt/acme.json
chmod 600 letsencrypt/acme.json

echo "===== Déploiement ====="

docker compose pull

docker compose up -d

echo "===== Installation Hugo ====="

apt install -y hugo

cd $INSTALL_DIR

if [ ! -d website/site ]; then
  hugo new site website/site
fi

echo "<h1>Plateforme Veille Technologique</h1>" > public/index.html

echo ""
echo "======================================"
echo "INSTALLATION TERMINEE"
echo "======================================"
echo ""
echo "PostgreSQL : $POSTGRES_DB"
echo "User       : $POSTGRES_USER"
echo "Password   : $POSTGRES_PASSWORD"
echo ""
echo "Configure maintenant tes DNS :"
echo ""
echo "watch.$DOMAIN"
echo "rss.$DOMAIN"
echo "n8n.$DOMAIN"
echo "portainer.$DOMAIN"
echo ""
echo "Puis attends la génération des certificats."
echo ""
#!/bin/bash

set -e

INSTALL_DIR="/opt/tech_watch"

echo "Stopping containers..."

cd $INSTALL_DIR

docker compose down -v || true

echo "Removing project directory..."

rm -rf $INSTALL_DIR

echo "Removing unused Docker resources..."

docker system prune -af --volumes

echo "Done."

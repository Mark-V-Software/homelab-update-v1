#!/bin/bash

REPO_DIR="homelab-update-v1"

if [ -d "$REPO_DIR" ]; then
    rm -rf "$REPO_DIR"
fi

git clone https://github.com/Mark-V-Software/homelab-update-v1.git
cd "$REPO_DIR"
chmod +x main-script.sh
sudo ./main-script.sh

#!/bin/bash

# Use strict mode
set -eufo pipefail

IFS=$'\n\t'

# Dump call
echo "⚙️ Launched: $(basename $0)" "$@"

sudo apt-get update
sudo apt-get install -y fortune
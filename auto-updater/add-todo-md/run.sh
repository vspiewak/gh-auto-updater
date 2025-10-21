#!/bin/bash

# Use strict mode
set -eufo pipefail

IFS=$'\n\t'

# Constants
readonly file='TODO.md'

# Dump call
echo "⚙️ Launched: $(basename $0)" "$@"

# Show a fortune (use init.sh)
echo "🥠 Show a fortune cookie"
fortune -s 

# Add TODO.md if not present
if [[ ! -f "$file" ]]; then
  echo '# TODO' > "$file"
  echo "✅ '$file' created"
  else 
  echo "❎ '$file' already exist"
fi

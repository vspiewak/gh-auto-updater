#!/bin/bash

# Use strict mode
set -eufo pipefail

IFS=$'\n\t'

# Constants
readonly file='FORTUNE.md'

# Dump call
echo "⚙️ Launched: $(basename $0)" "$@"

# Write FORTUNE.md
if [[ ! -f "$file" ]]; then
  echo '# FORTUNE' > "$file"
  echo "✅ '$file' created"
else 
  echo "❎ '$file' already exist"
fi

# Append a fortune
echo "🥠 Write a fortune cookie"
fortune -s >> "$file"
#!/bin/bash

# Use strict mode
set -eufo pipefail

IFS=$'\n\t'

# Dump call
echo "⚙️ Launched: $(basename $0)" "$@"

# Constants
readonly GITHUB_ORG='vspiewak'
readonly INPUT_SEPARATOR=','
#
readonly PR_LABEL='🤖 auto-updater'
readonly PR_LABEL_COLOR='#fef2c0'
readonly COMMIT_MSG_PREFIX='✨ Feature :'

# Script directory
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# Current directory
original_dir="$(pwd)"

# Create tmp dir
tmp_dir=$(mktemp -d)

# On EXIT
trap '
  rc=$?
  
  echo ""
  echo "🧹 Clean before exit"
  rm -rf "$tmp_dir"
  cd "$original_dir"

  if (( rc == 0 )); then
    echo "✅ Exited cleanly 💅🏻"
  else
    echo "❌ Exited with error (code: $rc)"
  fi

  ' EXIT

# Function: usage
usage() {
  cat <<'USAGE'
Usage:
  run.sh --repositories "<r1,r2,...>" --update-name "<name>"
Options:
  -r, --repositories   Comma-separated repositories
  -u, --update-name    Name of the update.
  -h, --help           Show this help and exit
USAGE
}

# Function: check dependency
check_dependency() {
  local bin=$1
  if ! command -v "$bin" &>/dev/null; then
    echo "Error: $bin not found in PATH"
    exit 1
  fi
}

repositories=""
update_name=""

# Parse args (supports short and long flags)
while [[ $# -gt 0 ]]; do
  case "$1" in
    -r | --repositories)
      [[ -n ${2:-} && ${2:0:1} != "-" ]] || {
        echo "Error: $1 requires a value."
        usage
        exit 1
      }
      repositories="$2"
      shift 2
      ;;
    -u | --update-name)
      [[ -n ${2:-} && ${2:0:1} != "-" ]] || {
        echo "Error: $1 requires a value."
        usage
        exit 1
      }
      update_name="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

# Validation: params
if [[ -z "$update_name" ]]; then
  echo "Error: --update-name is required."
  usage
  exit 1
fi

if [[ -z "$repositories" ]]; then
  echo "Error: --repositories is required."
  usage
  exit 1
fi

# Validation: update_name should contain a run.sh script
if [[ ! -d "$script_dir/$update_name" ]]; then
  echo "Error: directory '$update_name' not found"
  usage
  exit 1
fi

if [[ ! -f "$script_dir/$update_name/run.sh" ]]; then
  echo "Error: script run.sh not found in '$script_dir/$update_name' not found"
  usage
  exit 1
fi

# Check all dependencies
deps=("git" "gh" "jq")
for dep in "${deps[@]}"; do
  check_dependency "$dep"
done

repos=()

while IFS= read -r line; do
  repos+=("$line")
done < <(
  echo "$repositories" | tr "$INPUT_SEPARATOR" "\n" 
) 

echo "⚙️ repos: ${repos[@]}"

# Run init script if exist
if [[ -f "$script_dir/$update_name/init.sh" ]]; then
  echo "🛠️ Run init.sh"
  $script_dir/$update_name/init.sh
fi

# For each repos
for repo in "${repos[@]}"; do
 
  echo " "
  echo "---"
  echo " "

  # Log repo
  echo "🏗️ Repository '$repo'"

  # Fail-fast if repository not found
  if ! gh repo view "$GITHUB_ORG/$repo" > /dev/null 2>&1; then
    echo "❎ No repositories named '$repo' found"
    continue
  fi

  # Move to tmp_dir
  echo "🗂️ Will work in $tmp_dir"
  cd $tmp_dir

  # Delete branch (and close PR) if already exist
  update_name_no_slash=$(printf '%s' "$update_name" | sed 's|/|-|g')
  branch="feature/auto-updater-$update_name_no_slash"
  encoded_branch="${branch//\//%2F}"
  if gh api "repos/$GITHUB_ORG/$repo/branches/$encoded_branch" > /dev/null 2>&1; then
    echo "🗑️ Branch '$branch' already exist, deleting"
    gh api -X DELETE "repos/$GITHUB_ORG/$repo/git/refs/heads/$branch"
  fi

  # Clone repo
  echo "🧬 Cloning '$repo'"
  gh repo clone "$GITHUB_ORG/$repo" -- --depth=1

  # Go in repo
  cd $repo

  # Run script
  $script_dir/$update_name/run.sh "$repo"

  # If no changes to commit, skip
  if [[ -z "$(git status --porcelain)" ]]; then
    echo "❎ Nothing changed, skipping..."
    continue
  fi

  # Create branch
  echo "🌱 Create branch '$branch'"
  git checkout -b "$branch"

  # Add all files
  git add -A

  # Commit
  commit_msg="$COMMIT_MSG_PREFIX $update_name"
  echo "✍️ Commit '$commit_msg'"
  git commit -m "$commit_msg"

  # Push branch
  echo "📤 Pushing branch '$branch'"
  if ! git push -u origin "$branch"; then
    echo "❌ error while pushing $branch upstream"
    continue
  fi

  # Upsert auto-updater label
  echo "🏷️ Upsert label '$PR_LABEL' with color '$PR_LABEL_COLOR'"
  gh label create "$PR_LABEL" --repo "$GITHUB_ORG/$repo" -c "$PR_LABEL_COLOR" -f

  # Get base branch for PR
  base_branch=$(gh repo view "$GITHUB_ORG/$repo" --json defaultBranchRef --jq .defaultBranchRef.name)

  # Create PR
  echo "📨 Create Pull Request"
  if [[ -f "$script_dir/$update_name/PR.md" ]]; then
    cmd=(gh pr create \
    --base "$base_branch" \
    --head "$branch" \
    --label "$PR_LABEL" \
    --title "$commit_msg" \
    --body-file "$script_dir/$update_name/PR.md")
  else
    cmd=(gh pr create \
    --base "$base_branch" \
    --head "$branch" \
    --label "$PR_LABEL" \
    --fill)
  fi

  # Retry loop due to gh rate limit
  max=10
  delay=5
  for attempt in $(seq 1 "$max"); do
    if "${cmd[@]}"; then
      
      echo "✅ PR created [$attempt/$max]"

      # Print PR url
      pr_url=$(gh pr view "$branch" --repo "$GITHUB_ORG/$repo" --json 'url' -q '.url')
      echo "👀 $pr_url"

      break
    fi
    status=$?
    if (( attempt == max )); then
      echo "❌ gh pr create failed after $max attempts (exit $status)"
      break
    fi
    echo "⚠️ gh failed (exit $status). retrying in ${delay}s... [$attempt/$max]"
    sleep "$delay"
  done

done

echo ""
echo "✅ Everything done"
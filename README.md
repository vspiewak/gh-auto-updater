# GitHub Auto Updater 🤖

Open the **same pull request across many repositories** — from one command.

At work, this pattern has opened **27,000+ PRs** across a fleet of 2,700+ repos (83% merged, every one reviewed by a human).
This repo is the **minimal, runnable version** : fork it and get your first bot PR in ~10 minutes.

📝 Full story on the blog : [**gh-auto-updater : opening 27,000+ pull requests across a repo fleet**](https://vspiewak.com/gh-auto-updater-mass-pull-requests-across-a-repo-fleet)

## How it works

An *update* is a directory. That's the whole contract :

```text
auto-updater/
├── run.sh                  # the launcher (framework, written once)
├── add-todo-md/            # an updater
│   ├── run.sh              # the change itself
│   └── PR.md               # the pitch to humans
└── add-fortune-md/         # another updater
    ├── init.sh             # optional : install dependencies
    ├── run.sh
    └── PR.md
```

An updater's `run.sh` runs *inside a fresh clone* of each target repo and just... changes files.
Everything else — cloning, branching, committing, pushing, labeling, opening the PR — is the [launcher](./auto-updater/run.sh)'s job :

* 🌱 branch `feature/auto-updater-<name>`, commit `✨ Feature : <name>`
* ❎ **no-op detection** : nothing changed → no branch, no PR, no noise (updaters must be idempotent)
* 🗑️ **stale-branch delete** : re-running supersedes the previous PR — last run wins, no zombies
* 🏷️ every PR carries the `🤖 auto-updater` label → free audit trail *and* free metrics (one search query returns everything the bot ever proposed)
* ⚠️ retry loop with backoff for GitHub's rate limits

One principle rules the design : **the bot proposes, humans decide.**
No pushes to `main`, ever — only labeled, reviewable pull requests.

## Quick start 🚀

1. **Fork** this repo
2. Set `GITHUB_ORG` in [`auto-updater/run.sh`](./auto-updater/run.sh) to your username or org
3. Create a PAT with `repo` scope and add it as the `GH_AUTO_UPDATER_SECRET` Actions secret
4. Go to **Actions → ✨ Auto Updater → Run workflow**, target one of your repos, pick `add-todo-md`
5. Watch a labeled, reviewable PR appear on the target repo 🎉

See the results on the demo target : [**gh-auto-updater-sample-repo**](https://github.com/vspiewak/gh-auto-updater-sample-repo) — including a fortune cookie delivered by pull request 🥠

## Write your own updater

```bash
mkdir auto-updater/my-update
$EDITOR auto-updater/my-update/run.sh   # the change — make it idempotent !
$EDITOR auto-updater/my-update/PR.md    # the PR description humans will read
```

Add `my-update` to the workflow's `options` list, and you're fleet-ready.

#!/usr/bin/env bash
# Resume publication from the prepared workspace or an ordinary checkout.
set -euo pipefail

cd "$(dirname "$0")/.."
repository='Puneeth0106/Jenkins-Manufacturing-MLOps'
url="https://github.com/${repository}.git"
description='Manufacturing efficiency prediction with Flask and scikit-learn, delivered through Jenkins shared libraries, Docker, and Kubernetes.'

command -v git >/dev/null
command -v gh >/dev/null
gh auth status --hostname github.com
if [[ "$(gh api user --jq .login)" != 'Puneeth0106' ]]; then
    echo 'Authenticate as Puneeth0106 before publishing.' >&2
    exit 1
fi

# The preparation environment may prohibit writes to the root .git directory.
if [[ ! -e .git ]]; then
    if [[ ! -d local-backup/publication.git ]]; then
        echo 'No local Git history found. Run from the prepared project or a Git checkout.' >&2
        exit 1
    fi
    cp -R local-backup/publication.git .git
    git config --local --unset core.worktree
fi

git rev-parse --verify main >/dev/null
git rev-parse --verify archive/shared-library >/dev/null
if [[ -n "$(git status --porcelain)" ]]; then
    echo 'Commit or set aside pending project changes before publishing.' >&2
    exit 1
fi
if git remote get-url origin >/dev/null 2>&1; then
    existing_url="$(git remote get-url origin)"
    case "$existing_url" in
        "$url"|"https://github.com/${repository}"|"git@github.com:${repository}.git") ;;
        *) echo "Existing origin differs: ${existing_url}. Inspect it before proceeding." >&2; exit 1 ;;
    esac
fi

response_dir="$(mktemp -d)"
trap 'rm -rf "$response_dir"' EXIT
if gh api "repos/${repository}" >"${response_dir}/repository.json" 2>"${response_dir}/error"; then
    if [[ "$(gh repo view "$repository" --json visibility --jq .visibility)" != 'PUBLIC' ]]; then
        echo 'A non-public repository already uses this name. Inspect it before changing its visibility.' >&2
        exit 1
    fi
elif grep -q '(HTTP 404)' "${response_dir}/error"; then
    gh repo create "$repository" --public --description "$description"
else
    cat "${response_dir}/error" >&2
    echo 'Repository lookup failed; no repository was created.' >&2
    exit 1
fi

if ! git remote get-url origin >/dev/null 2>&1; then
    git remote add origin "$url"
fi
git fetch origin
if git show-ref --verify --quiet refs/remotes/origin/main; then
    if ! git merge-base --is-ancestor origin/main main; then
        echo 'Remote main contains history absent locally. Inspect and merge it before rerunning; no force-push was attempted.' >&2
        exit 1
    fi
fi

git push --atomic --set-upstream origin main archive/shared-library
gh repo edit "$repository" --description "$description" --default-branch main \
    --add-topic jenkins --add-topic ci-cd --add-topic mlops \
    --add-topic flask --add-topic scikit-learn --add-topic docker \
    --add-topic kubernetes --add-topic machine-learning --add-topic manufacturing

for branch in main archive/shared-library; do
    local_sha="$(git rev-parse "$branch")"
    remote_sha="$(git ls-remote origin "refs/heads/${branch}" | awk '{print $1}')"
    if [[ "$local_sha" != "$remote_sha" ]]; then
        echo "Remote verification failed for ${branch}." >&2
        exit 1
    fi
done
if [[ "$(gh repo view "$repository" --json visibility --jq .visibility)" != 'PUBLIC' ]]; then
    echo 'Public visibility verification failed.' >&2
    exit 1
fi
gh repo view "$repository" --json url,visibility,description,repositoryTopics,defaultBranchRef

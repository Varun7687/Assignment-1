#!/bin/bash
# Update ONLY the existing shared website/Git permissions and GitHub remote.
# Does not create users, change SSH keys, mount/format disks, or write HTML.
# Run on the working EC2 instance with its existing volume mounted.
set -Eeuo pipefail
readonly SITE_DIR="/data/www/status"
readonly GITHUB_REPOSITORY_URL="${GITHUB_REPOSITORY_URL:-}"
if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: run as root with sudo." >&2; exit 1
fi
for command in git setfacl runuser mountpoint getent; do
  command -v "$command" >/dev/null || { echo "ERROR: missing required command: $command" >&2; exit 1; }
done
mountpoint -q /data/www || { echo "ERROR: /data/www must already be mounted." >&2; exit 1; }
[[ -s "$SITE_DIR/index.html" ]] || { echo "ERROR: existing website not found; stopping." >&2; exit 1; }
getent group webteam >/dev/null || { echo "ERROR: existing webteam group not found." >&2; exit 1; }
for account in asha ravi; do
  id "$account" >/dev/null || { echo "ERROR: existing account $account not found." >&2; exit 1; }
done
# Preserve existing group memberships while ensuring both accounts are members.
for account in asha ravi; do
  usermod -aG webteam "$account"
done

# Keep one trusted shared working tree; do not reset branches or existing work.
# This design is for mutually trusted team members, not production isolation.
if [[ -L "$SITE_DIR" || -L "$SITE_DIR/.git" ]]; then
  echo "ERROR: refusing a symlinked site or Git metadata directory." >&2
  exit 1
fi
if [[ -e "$SITE_DIR/.git" && ! -d "$SITE_DIR/.git" ]]; then
  echo "ERROR: linked Git worktrees are not supported by this shared setup." >&2
  exit 1
fi
GITHUB_URL_PATTERN='^(https://github\.com/|git@github\.com:)[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9_.-]+\.git$'
if [[ -n "$GITHUB_REPOSITORY_URL" && ! "$GITHUB_REPOSITORY_URL" =~ $GITHUB_URL_PATTERN ]]; then
  echo "ERROR: use https://github.com/OWNER/REPO.git or git@github.com:OWNER/REPO.git, without credentials." >&2
  exit 1
fi

# Trust only this exact path, separately for root, Asha, and Ravi.
for account in root asha ravi; do
  if ! runuser -u "$account" -- git config --global --fixed-value --get-all safe.directory "$SITE_DIR" >/dev/null; then
    runuser -u "$account" -- git config --global --add safe.directory "$SITE_DIR"
  fi
done

NEW_REPOSITORY=0
if [[ ! -d "$SITE_DIR/.git" ]]; then
  git -C "$SITE_DIR" init --shared=group --initial-branch=assignment-1
  NEW_REPOSITORY=1
fi

# Refuse an unexpected existing remote rather than silently changing it.
if [[ -n "$GITHUB_REPOSITORY_URL" ]]; then
  if git -C "$SITE_DIR" remote | grep -Fxq origin; then
    EXISTING_REMOTE="$(git -C "$SITE_DIR" remote get-url origin)"
    if [[ "$EXISTING_REMOTE" != "$GITHUB_REPOSITORY_URL" ]]; then
      echo "ERROR: origin already points elsewhere. Review git remote -v; it was not changed." >&2
      exit 1
    fi
    # Also reject a separate push destination; never publish to a surprise URL.
    while IFS= read -r push_url; do
      if [[ "$push_url" != "$GITHUB_REPOSITORY_URL" ]]; then
        echo "ERROR: origin has a different push destination. Review it manually." >&2
        exit 1
      fi
    done < <(git -C "$SITE_DIR" remote get-url --push --all origin)
  else
    git -C "$SITE_DIR" remote add origin "$GITHUB_REPOSITORY_URL"
  fi
fi

git -C "$SITE_DIR" config core.sharedRepository group
# Only a genuinely new repository receives the bootstrap commit.
# An existing repository's branch, staging area and uncommitted work stay intact.
if [[ "$NEW_REPOSITORY" -eq 1 ]]; then
  git -C "$SITE_DIR" add -- index.html
  if [[ -f "$SITE_DIR/README.md" ]]; then
    git -C "$SITE_DIR" add -- README.md
  fi
  git -C "$SITE_DIR" -c core.hooksPath=/dev/null -c core.fsmonitor=false \
    -c user.name="Assignment 1 Bootstrap" -c user.email="assignment-1@localhost.invalid" \
    commit -m "Bootstrap Assignment 1 status page"
fi

# Shared file access, including files created by future editor/Git operations.
chgrp -R webteam "$SITE_DIR"
chmod -R g+rwX "$SITE_DIR"
find "$SITE_DIR" -type d -exec chmod g+s {} +
setfacl -R -m g:webteam:rwX "$SITE_DIR"
find "$SITE_DIR" -type d -exec setfacl -m d:u::rwx,d:g::rwx,d:g:webteam:rwx,d:m::rwx,d:o::r-x {} +

# Git metadata is shared by webteam but inaccessible to other ordinary users.
chmod -R g+rwX,o-rwx "$SITE_DIR/.git"
setfacl -R -m g:webteam:rwX,o::--- "$SITE_DIR/.git"
find "$SITE_DIR/.git" -type d -exec chmod g+s {} +
find "$SITE_DIR/.git" -type d -exec setfacl -m d:u::rwx,d:g::rwx,d:g:webteam:rwx,d:m::rwx,d:o::--- {} +

if [[ -n "$GITHUB_REPOSITORY_URL" ]]; then
  echo "GitHub origin configured. No fetch, pull, commit of existing work, or push was performed."
else
  echo "GitHub URL is not set; shared access is configured and any existing origin is retained."
fi

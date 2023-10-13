#!/usr/bin/env bash
### Ref: http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -exo pipefail

### Import Environment Variables & arguments
ENV_GITHUB_RUN_ID="${GITHUB_RUN_ID}"
ARG_DIR_SOURCE=${1}
ARG_SCRIPT_BUILD=${2}
set -u

DIR_WORKSPACE="$(pwd)"
DIR_TMP_GHP="/tmp/gh-pages"
CURRENT_BRANCH=$(git branch --show-current)

if [ -n "${ARG_SCRIPT_BUILD}" ] && [ ! -x "${ARG_SCRIPT_BUILD}" ]; then
  echo "The build script '${ARG_SCRIPT_BUILD}' either does not exists or is not executable!"
  exit 1
fi

if [[ -n "${ENV_GITHUB_RUN_ID}" ]]; then
  git config user.name github-actions
  git config user.email github-actions@github.com
fi

### Ensure the 'gh-pages' orphan branch exists
! git checkout --orphan gh-pages >> /dev/null
if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
  git reset --hard
  git commit --allow-empty -m "Initial gh-pages commit"
  git checkout "${CURRENT_BRANCH}"
  echo "Orphan branch 'gh-pages' created."
fi

if [ -n "${ARG_SCRIPT_BUILD}" ]; then
  ! "${ARG_SCRIPT_BUILD}"
  if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    echo "The build script '${ARG_SCRIPT_BUILD}' exited with a non 0!"
    exit 2
  fi

  ### After build script ensure that we are in the workspace directory
  cd "${DIR_WORKSPACE}"
fi

if [ ! -d "${ARG_DIR_SOURCE}" ] || [ ! -r "${ARG_DIR_SOURCE}" ]; then
  echo "Source directory must exist and be readable, path must be relative to the root of the project."
  exit 3
fi

### Clean up worktree and /tmp dir
! rm -rf "${DIR_TMP_GHP}" >> /dev/null
! git worktree remove /tmp/gh-pages >> /dev/null

### Copy gh-pages source to worktree
git worktree add "${DIR_TMP_GHP}" gh-pages
rm -rf "${DIR_TMP_GHP:?}/*"
cp -r "${ARG_DIR_SOURCE:?}"/* "${DIR_TMP_GHP}/"

### Publish gh-pages
cd "${DIR_TMP_GHP}"
git add --all

### Allow the commit to fail, as not all commits alter the GitHub Pages
! git commit -m "action-ghp-sync update"
if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
  git push -f origin gh-pages
  echo "✅ GitHub Pages published successfully!"
else
  echo "☑ No changes detected"
fi

cd "${DIR_WORKSPACE}"

### Clean up worktree and /tmp dir
! rm -rf "${DIR_TMP_GHP}" >> /dev/null
! git worktree remove /tmp/gh-pages >> /dev/null

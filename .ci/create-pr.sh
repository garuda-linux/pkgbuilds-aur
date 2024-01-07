#!/usr/bin/env bash
set -euo pipefail

# $1: pkgbase

if [ -z "${ACCESS_TOKEN:-}" ];
then
    echo "ERROR: ACCESS_TOKEN is not set. Please set it to a valid access token to use human review or disable CI_HUMAN_REVIEW."
    exit 0
fi

# $1: pkgbase
# $2: branch
# $3: target branch
function create_gitlab_pr() {
    local pkgbase="$1"
    local branch="$2"
	local target_branch="$3"

	# Taken from https://about.gitlab.com/2017/09/05/how-to-automatically-create-a-new-mr-on-gitlab-with-gitlab-ci/
	# Require a list of all the merge request and take a look if there is already
	# one with the same source branch
	local _COUNTBRANCHES _LISTMR _MR_EXISTS BODY
	if ! _LISTMR=$(curl --fail-with-body --silent "https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/merge_requests?state=opened" --header "PRIVATE-TOKEN:${ACCESS_TOKEN}"); then
		echo "ERROR: $pkgbase: Failed to get list of merge requests." >&2
		return
	fi

	_COUNTBRANCHES=$(grep -o "\"source_branch\":\"${branch}\"" <<< "${_LISTMR}" | wc -l || true)

	if [ "${_COUNTBRANCHES}" == "0" ]; then
		_MR_EXISTS=0
	else
		_MR_EXISTS=1
	fi

	# The description of our new MR, we want to remove the branch after the MR has
	# been closed
	BODY="{
	\"project_id\": ${CI_PROJECT_ID},
	\"source_branch\": \"${branch}\",
	\"target_branch\": \"${target_branch}\",
	\"remove_source_branch\": true,
	\"force_remove_source_branch\": false,
	\"allow_collaboration\": true,
	\"subscribed\" : false,
	\"approvals_before_merge\": \"1\",
	\"title\": \"chore($pkgbase): PKGBUILD modified [deploy $pkgbase]\",
	\"description\": \"The recent update of this package requires human review!\",
	\"labels\": \"ci,human-review,update\"
	}"

	# No MR found, let's create a new one
	if [ "$_MR_EXISTS" == 0 ]; then
		curl --fail-with-body -s -X POST "https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/merge_requests" \
			--header "PRIVATE-TOKEN:${ACCESS_TOKEN}" \
			--header "Content-Type: application/json" \
			--data "${BODY}" && echo "$pkgbase: Created merge request." || echo "ERROR: $pkgbase: Failed to create merge request." >&2
	else
		echo "$pkgbase: No new merge request opened due to an already existing MR."
	fi
}

# $1: pkgbase
# $2: branch
# $3: target branch
function create_github_pr() {
	local pkgbase="$1"
	local branch="$2"
	local target_branch="$3"

	# Taken from https://about.gitlab.com/2017/09/05/how-to-automatically-create-a-new-mr-on-gitlab-with-gitlab-ci/
	# Require a list of all the merge request and take a look if there is already
	# one with the same source branch
	local _COUNTBRANCHES _LISTMR _MR_EXISTS BODY
	if ! _LISTMR=$(curl --fail-with-body --silent "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/pulls?state=open&head=$GITHUB_REPOSITORY_OWNER:$branch" \
		-H "Accept: application/vnd.github+json" \
		-H "X-GitHub-Api-Version: 2022-11-28" \
		-H "Authorization: token ${ACCESS_TOKEN}"); then
		echo "ERROR: $pkgbase: Failed to get list of pull requests." >&2
		return
	fi

	_COUNTBRANCHES=$(jq length <<< "${_LISTMR}" || true)

	if [ "${_COUNTBRANCHES}" == "0" ]; then
		_MR_EXISTS=0
	else
		_MR_EXISTS=1
	fi

	# The description of our new MR, we want to remove the branch after the MR has
	# been closed
	BODY="{
	\"head\": \"${branch}\",
	\"base\": \"${target_branch}\",
	\"maintainer_can_modify\": true,
	\"title\": \"chore($pkgbase): PKGBUILD modified [deploy $pkgbase]\",
	\"body\": \"The recent update of this package requires human review!\"
	}"

	# No MR found, let's create a new one
	if [ "$_MR_EXISTS" == 0 ]; then
		# PR doesn't exist, create a new one
		curl --fail-with-body -s -X POST "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/pulls" \
			-H "Accept: application/vnd.github+json" \
			-H "X-GitHub-Api-Version: 2022-11-28" \
			-H "Authorization: token ${ACCESS_TOKEN}" \
			--data "${BODY}" && echo "$pkgbase: Created pull request." || echo "ERROR: $pkgbase Failed to create pull request." >&2
	else
		echo "$pkgbase: No new pull request opened due to an already existing MR."
	fi
}	

# $1: branch
# $2: target branch
# $3: pkgbase
function manage_branch() {
    local branch="$1"
	local target_branch="$2"
	local pkgbase="$3"

	git stash
    if git show-ref --quiet "origin/$branch"; then
		git switch "$branch"
		git checkout stash -- "$pkgbase"
        # Branch already exists, let's see if it's up to date
		# Also check if previous parent commit is no longer ancestor of target_branch
		if ! git diff --staged --exit-code --quiet || ! git merge-base --is-ancestor HEAD^ "origin/$target_branch"; then
			# Not up to date
			git reset --hard "origin/$target_branch"
			git checkout stash -- "$pkgbase"
			git commit -m "chore($1): PKGBUILD modified [deploy $pkgbase]"
		fi
	else
		# Branch does not exist, let's create it
		git switch -C "$branch" "origin/$target_branch"
		git checkout stash -- "$pkgbase"
		git commit -m "chore($1): PKGBUILD modified [deploy $pkgbase]"
	fi
	git stash drop
}

PKGBASE="$1"

if [ -v CI_COMMIT_REF_NAME ]; then
	TARGET_BRANCH="$CI_COMMIT_REF_NAME"
elif [ -v GITHUB_REF_NAME ]; then
	TARGET_BRANCH="$GITHUB_REF_NAME"
else
	# Current branch name
	TARGET_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
fi

ORIGINAL_REF="$(git rev-parse HEAD)"
CHANGE_BRANCH="$PKGBASE"

manage_branch "$CHANGE_BRANCH" "$TARGET_BRANCH" "$PKGBASE"

if [ -v GITLAB_CI ]; then
	create_gitlab_pr "$PKGBASE" "$CHANGE_BRANCH" "$TARGET_BRANCH"
elif [ -v GITHUB_ACTIONS ]; then
	create_github_pr "$PKGBASE" "$CHANGE_BRANCH" "$TARGET_BRANCH"
else
    echo "WARNING: Pull request creation is only supported on GitLab CI/GitHub Actions. Please disable CI_HUMAN_REVIEW." >&2
	exit 0
fi

git push --force-with-lease origin "$CHANGE_BRANCH"

# Switch back to the original branch
git -c advice.detachedHead=false checkout "$ORIGINAL_REF"
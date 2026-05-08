#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: h2-fetch-workflow-artifact.sh

Download an artifact from the latest successful run of a GitHub Actions workflow.

Environment:
  WORKFLOW_ID     Workflow file name, for example picolibc-builder.yml. Required.
  ARTIFACT_NAME   Artifact name to download. Required.
  DEST_DIR        Destination directory. Required.
  REPO            GitHub repository, owner/name. Defaults to current gh repo.
  BRANCH          Optional workflow branch filter.
  MAX_AGE_HOURS   Maximum run age. Defaults to 30.
  RUN_ID          Optional workflow run id. Skips latest-run lookup when set.
  FETCH_RUN_ID_FILE Optional file where the selected run id is written.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

: "${WORKFLOW_ID:?WORKFLOW_ID is required}"
: "${ARTIFACT_NAME:?ARTIFACT_NAME is required}"
: "${DEST_DIR:?DEST_DIR is required}"

if ! command -v gh >/dev/null 2>&1; then
  echo "error: gh is required" >&2
  exit 1
fi

repo="${REPO:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
branch="${BRANCH:-}"
max_age_seconds=$(( ${MAX_AGE_HOURS:-30} * 3600 ))

mkdir -p "${DEST_DIR}"

run_id="${RUN_ID:-}"

if [[ -z "${run_id}" ]]; then
  if ! command -v jq >/dev/null 2>&1; then
    echo "error: jq is required" >&2
    exit 1
  fi

  runs_json="$(gh run list \
    --repo "${repo}" \
    --workflow "${WORKFLOW_ID}" \
    --status success \
    --limit 30 \
    --json databaseId,createdAt,headBranch,conclusion)"

  run_id="$(jq -r \
    --arg branch "${branch}" \
    --argjson max_age "${max_age_seconds}" \
    '[.[] | select(($branch == "" or .headBranch == $branch) and ((now - (.createdAt | fromdateiso8601)) <= $max_age))][0].databaseId // empty' \
    <<<"${runs_json}")"
fi

if [[ -z "${run_id}" ]]; then
  echo "error: no successful ${WORKFLOW_ID} run found within ${MAX_AGE_HOURS:-30} hours" >&2
  if [[ -n "${branch}" ]]; then
    echo "branch filter: ${branch}" >&2
  fi
  exit 1
fi

if [[ -n "${FETCH_RUN_ID_FILE:-}" ]]; then
  printf '%s\n' "${run_id}" >"${FETCH_RUN_ID_FILE}"
fi

echo "Downloading artifact ${ARTIFACT_NAME} from ${repo} workflow ${WORKFLOW_ID} run ${run_id}"
gh run download "${run_id}" \
  --repo "${repo}" \
  --name "${ARTIFACT_NAME}" \
  --dir "${DEST_DIR}"

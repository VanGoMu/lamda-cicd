#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:?Define AWS_REGION}"
: "${GITHUB_OWNER:?Define GITHUB_OWNER}"
: "${GITHUB_REPOSITORY:?Define GITHUB_REPOSITORY como owner/repo o solo repo}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPOSITORY="${GITHUB_REPOSITORY#${GITHUB_OWNER}/}"
STACK_NAME="${BOOTSTRAP_STACK_NAME:-lambda-cicd-bootstrap}"

if [[ -z "${GITHUB_ORGANIZATION_ID:-}" || -z "${GITHUB_REPOSITORY_ID:-}" ]]; then
  command -v curl >/dev/null || {
    printf 'curl es obligatorio para detectar los IDs de GitHub; define ambos manualmente\n' >&2
    exit 1
  }
  command -v jq >/dev/null || {
    printf 'jq es obligatorio para detectar los IDs de GitHub; define ambos manualmente\n' >&2
    exit 1
  }
  api_url="${GITHUB_API_URL:-https://api.github.com}"
  auth_header=()
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    auth_header=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
  fi
  read -r detected_organization_id detected_repository_id < <(
    curl --fail --silent --show-error \
      -H 'Accept: application/vnd.github+json' \
      -H 'X-GitHub-Api-Version: 2022-11-28' \
      "${auth_header[@]}" \
      "${api_url}/repos/${GITHUB_OWNER}/${REPOSITORY}" \
      | jq -r '[.owner.id, .id] | @tsv'
  )
  GITHUB_ORGANIZATION_ID="${GITHUB_ORGANIZATION_ID:-$detected_organization_id}"
  GITHUB_REPOSITORY_ID="${GITHUB_REPOSITORY_ID:-$detected_repository_id}"
fi

aws cloudformation deploy \
  --region "$AWS_REGION" \
  --stack-name "$STACK_NAME" \
  --template-file "$ROOT_DIR/infrastructure/bootstrap.yaml" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    "GitHubOrganization=${GITHUB_OWNER}" \
    "GitHubRepository=${REPOSITORY}" \
    "GitHubOrganizationId=${GITHUB_ORGANIZATION_ID}" \
    "GitHubRepositoryId=${GITHUB_REPOSITORY_ID}"

aws cloudformation describe-stacks --region "$AWS_REGION" --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs' --output table

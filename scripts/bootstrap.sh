#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:?Define AWS_REGION}"
: "${GITHUB_OWNER:?Define GITHUB_OWNER}"
: "${GITHUB_REPOSITORY:?Define GITHUB_REPOSITORY como owner/repo o solo repo}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPOSITORY="${GITHUB_REPOSITORY#${GITHUB_OWNER}/}"
STACK_NAME="${BOOTSTRAP_STACK_NAME:-lambda-cicd-bootstrap}"

aws cloudformation deploy \
  --region "$AWS_REGION" \
  --stack-name "$STACK_NAME" \
  --template-file "$ROOT_DIR/infrastructure/bootstrap.yaml" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    "GitHubOrganization=${GITHUB_OWNER}" \
    "GitHubRepository=${REPOSITORY}"

aws cloudformation describe-stacks --region "$AWS_REGION" --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs' --output table

#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:?Define AWS_REGION}"
STACK_NAME="${STACK_NAME:-lambda-cicd-demo}"

printf 'Esto elimina la stack %s y puede borrar recursos con coste. Continuar? [y/N] ' "$STACK_NAME"
read -r answer
[[ "$answer" == "y" || "$answer" == "Y" ]] || exit 0
aws cloudformation delete-stack --region "$AWS_REGION" --stack-name "$STACK_NAME"
printf 'Borrado solicitado. Revisa el estado antes de eliminar bucket, versiones y secreto.\n'

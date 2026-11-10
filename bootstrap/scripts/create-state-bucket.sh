#!/usr/bin/env bash
set -euo pipefail

: "${STATE_BUCKET_NAME:?STATE_BUCKET_NAME nao informado}"
: "${STATE_BUCKET_REGION:?STATE_BUCKET_REGION nao informado}"

head_error_file="$(mktemp)"
trap 'rm -f "$head_error_file"' EXIT

if aws s3api head-bucket --bucket "$STATE_BUCKET_NAME" 2>"$head_error_file"; then
  echo "Bucket S3 $STATE_BUCKET_NAME ja existe e sera reutilizado."
  exit 0
fi

# So tente criar quando a AWS confirmar que o nome nao existe. Um 403 pode
# significar que o nome global pertence a outra conta; qualquer outro erro
# (incluindo credenciais expiradas) tambem deve interromper o bootstrap.
if ! grep -Eq '\(404\)|Not Found' "$head_error_file"; then
  cat "$head_error_file" >&2
  exit 1
fi

if [[ "$STATE_BUCKET_REGION" == "us-east-1" ]]; then
  aws s3api create-bucket \
    --bucket "$STATE_BUCKET_NAME" \
    --region "$STATE_BUCKET_REGION"
else
  aws s3api create-bucket \
    --bucket "$STATE_BUCKET_NAME" \
    --region "$STATE_BUCKET_REGION" \
    --create-bucket-configuration "LocationConstraint=$STATE_BUCKET_REGION"
fi

echo "Bucket S3 $STATE_BUCKET_NAME criado em $STATE_BUCKET_REGION."

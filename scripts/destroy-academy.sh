#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
ENVIRONMENT_DIR="${PROJECT_DIR}/environments/homolog"

AWS_REGION_VALUE="${AWS_REGION:-us-east-1}"
STATE_BUCKET="${TF_STATE_BUCKET:-}"
EXPECTED_ACCOUNT_ID="${EXPECTED_AWS_ACCOUNT_ID:-}"
DELETE_STATE_BUCKET=false
AUTO_APPROVE=false

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/destroy-academy.sh --state-bucket NOME [opcoes]

Opcoes:
  --state-bucket NOME       Bucket S3 que armazena o state do ambiente.
  --region REGIAO           Regiao AWS (padrao: AWS_REGION ou us-east-1).
  --account-id ID           Conta AWS Academy esperada (12 digitos).
  --delete-state-bucket     Apaga tambem o bucket e todas as versoes do state.
  --auto-approve            Nao solicita confirmacao interativa. Exige --account-id.
  -h, --help                Exibe esta ajuda.

Credenciais temporarias devem estar configuradas em AWS_ACCESS_KEY_ID,
AWS_SECRET_ACCESS_KEY e AWS_SESSION_TOKEN.
USAGE
}

fail() {
  echo "Erro: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "comando obrigatorio nao encontrado: $1"
}

while (($# > 0)); do
  case "$1" in
    --state-bucket)
      (($# >= 2)) || fail "informe um valor para --state-bucket"
      STATE_BUCKET="$2"
      shift 2
      ;;
    --region)
      (($# >= 2)) || fail "informe um valor para --region"
      AWS_REGION_VALUE="$2"
      shift 2
      ;;
    --account-id)
      (($# >= 2)) || fail "informe um valor para --account-id"
      EXPECTED_ACCOUNT_ID="$2"
      shift 2
      ;;
    --delete-state-bucket)
      DELETE_STATE_BUCKET=true
      shift
      ;;
    --auto-approve)
      AUTO_APPROVE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "opcao desconhecida: $1"
      ;;
  esac
done

[[ -n "${STATE_BUCKET}" ]] || fail "use --state-bucket ou defina TF_STATE_BUCKET"
[[ "${AWS_REGION_VALUE}" =~ ^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$ ]] || fail "regiao AWS invalida: ${AWS_REGION_VALUE}"
[[ -z "${EXPECTED_ACCOUNT_ID}" || "${EXPECTED_ACCOUNT_ID}" =~ ^[0-9]{12}$ ]] || fail "account ID deve possuir 12 digitos"

require_command aws
require_command terraform

CURRENT_ACCOUNT_ID="$(aws sts get-caller-identity --region "${AWS_REGION_VALUE}" --query Account --output text)"
[[ "${CURRENT_ACCOUNT_ID}" =~ ^[0-9]{12}$ ]] || fail "nao foi possivel identificar a conta AWS"

if [[ -n "${EXPECTED_ACCOUNT_ID}" && "${CURRENT_ACCOUNT_ID}" != "${EXPECTED_ACCOUNT_ID}" ]]; then
  fail "conta autenticada (${CURRENT_ACCOUNT_ID}) difere da conta esperada (${EXPECTED_ACCOUNT_ID})"
fi

aws s3api head-bucket --bucket "${STATE_BUCKET}" >/dev/null

echo
echo "ATENCAO: esta operacao e destrutiva."
echo "Conta AWS : ${CURRENT_ACCOUNT_ID}"
echo "Regiao    : ${AWS_REGION_VALUE}"
echo "Ambiente  : homolog"
echo "State S3  : ${STATE_BUCKET}"
echo "Apagar S3 : ${DELETE_STATE_BUCKET}"
echo

if [[ "${AUTO_APPROVE}" == true ]]; then
  [[ -n "${EXPECTED_ACCOUNT_ID}" ]] || fail "--auto-approve exige --account-id ou EXPECTED_AWS_ACCOUNT_ID"
else
  CONFIRMATION="destroy ${CURRENT_ACCOUNT_ID} homolog"
  read -r -p "Digite '${CONFIRMATION}' para continuar: " ANSWER
  [[ "${ANSWER}" == "${CONFIRMATION}" ]] || fail "confirmacao incorreta; nenhuma alteracao foi realizada"
fi

# Variaveis obrigatorias ainda precisam existir para o Terraform carregar a
# configuracao durante o destroy. Estes valores nao sao aplicados a recursos.
export AWS_REGION="${AWS_REGION_VALUE}"
export AWS_DEFAULT_REGION="${AWS_REGION_VALUE}"
export TF_IN_AUTOMATION=true
export TF_INPUT=false
export TF_VAR_lab_role_arn="${TF_VAR_lab_role_arn:-arn:aws:iam::${CURRENT_ACCOUNT_ID}:role/LabRole}"
export TF_VAR_eks_public_access_cidrs="${TF_VAR_eks_public_access_cidrs:-[\"0.0.0.0/0\"]}"
export TF_VAR_auth_db_password="${TF_VAR_auth_db_password:-destroy-only-placeholder-auth}"
export TF_VAR_flags_db_password="${TF_VAR_flags_db_password:-destroy-only-placeholder-flags}"
export TF_VAR_targeting_db_password="${TF_VAR_targeting_db_password:-destroy-only-placeholder-targeting}"
export TF_VAR_auth_master_key="${TF_VAR_auth_master_key:-destroy-only-placeholder-auth-master-key}"
export TF_VAR_evaluation_service_api_key="${TF_VAR_evaluation_service_api_key:-destroy-only-placeholder-evaluation-key}"

echo "Inicializando o backend remoto..."
terraform -chdir="${ENVIRONMENT_DIR}" init -reconfigure \
  -backend-config="bucket=${STATE_BUCKET}" \
  -backend-config="region=${AWS_REGION_VALUE}" \
  -backend-config="use_lockfile=true"

if [[ -z "$(terraform -chdir="${ENVIRONMENT_DIR}" state list)" ]]; then
  echo "O state do ambiente ja esta vazio; nao ha recursos Terraform para destruir."
else
  echo "Gerando o plano de destruicao..."
  DESTROY_PLAN="$(mktemp "${TMPDIR:-/tmp}/togglemaster-destroy.XXXXXX")"
  trap 'rm -f -- "${DESTROY_PLAN:-}"' EXIT

  terraform -chdir="${ENVIRONMENT_DIR}" plan -destroy -out="${DESTROY_PLAN}"
  terraform -chdir="${ENVIRONMENT_DIR}" apply -auto-approve "${DESTROY_PLAN}"

  if [[ -n "$(terraform -chdir="${ENVIRONMENT_DIR}" state list)" ]]; then
    fail "o Terraform terminou, mas o state ainda possui recursos"
  fi
fi

if [[ "${DELETE_STATE_BUCKET}" == true ]]; then
  require_command python3
  echo "Removendo todas as versoes e delete markers do bucket de state..."

  aws s3api list-object-versions --bucket "${STATE_BUCKET}" --output json |
    python3 -c 'import json, sys
data = json.load(sys.stdin)
for group in ("Versions", "DeleteMarkers"):
    for item in data.get(group, []):
        print("{}\t{}".format(item["Key"], item["VersionId"]))' |
    while IFS=$'\t' read -r object_key version_id; do
      [[ -n "${object_key}" && -n "${version_id}" ]] || continue
      aws s3api delete-object \
        --bucket "${STATE_BUCKET}" \
        --key "${object_key}" \
        --version-id "${version_id}" >/dev/null
    done

  aws s3api delete-bucket --bucket "${STATE_BUCKET}" --region "${AWS_REGION_VALUE}"
  echo "Bucket de state removido: ${STATE_BUCKET}"
fi

echo "Destruicao concluida. Nenhum recurso permanece no state do ambiente homolog."
if [[ "${DELETE_STATE_BUCKET}" == false ]]; then
  echo "O bucket de state foi preservado. Para apaga-lo, repita com --delete-state-bucket."
fi

#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
ENVIRONMENT_DIR="${PROJECT_DIR}/environments/homolog"
PROFILE_FILE="profiles/personal-demo.tfvars"
STATE_KEY="togglemaster/personal-demo/homolog/terraform.tfstate"

AWS_REGION_VALUE="${AWS_REGION:-us-east-1}"
STATE_REGION="${TF_STATE_REGION:-us-east-2}"
STATE_BUCKET="${TF_STATE_BUCKET:-}"
EXPECTED_ACCOUNT_ID="${EXPECTED_AWS_ACCOUNT_ID:-}"
AUTO_APPROVE=false

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/destroy-personal-demo.sh --state-bucket NOME [opcoes]

Opcoes:
  --state-bucket NOME  Bucket S3 que armazena o state personal-demo.
  --region REGIAO      Regiao dos recursos AWS (padrao: AWS_REGION ou us-east-1).
  --state-region REGIAO Regiao do bucket de state (padrao: TF_STATE_REGION ou us-east-2).
  --account-id ID      Conta AWS esperada (12 digitos).
  --auto-approve       Nao solicita confirmacao. Exige --account-id.
  -h, --help           Exibe esta ajuda.

O script usa exclusivamente o state:
  togglemaster/personal-demo/homolog/terraform.tfstate
USAGE
}

fail() {
  echo "Erro: $*" >&2
  exit 1
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
    --state-region)
      (($# >= 2)) || fail "informe um valor para --state-region"
      STATE_REGION="$2"
      shift 2
      ;;
    --account-id)
      (($# >= 2)) || fail "informe um valor para --account-id"
      EXPECTED_ACCOUNT_ID="$2"
      shift 2
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

[[ -n "$STATE_BUCKET" ]] || fail "use --state-bucket ou defina TF_STATE_BUCKET"
[[ "$AWS_REGION_VALUE" =~ ^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$ ]] || fail "regiao AWS invalida: $AWS_REGION_VALUE"
[[ "$STATE_REGION" =~ ^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$ ]] || fail "regiao do state invalida: $STATE_REGION"
[[ -z "$EXPECTED_ACCOUNT_ID" || "$EXPECTED_ACCOUNT_ID" =~ ^[0-9]{12}$ ]] || fail "account ID deve possuir 12 digitos"
command -v aws >/dev/null 2>&1 || fail "comando obrigatorio nao encontrado: aws"
command -v terraform >/dev/null 2>&1 || fail "comando obrigatorio nao encontrado: terraform"

CURRENT_ACCOUNT_ID="$(aws sts get-caller-identity --region "$AWS_REGION_VALUE" --query Account --output text)"
[[ "$CURRENT_ACCOUNT_ID" =~ ^[0-9]{12}$ ]] || fail "nao foi possivel identificar a conta AWS"

if [[ -n "$EXPECTED_ACCOUNT_ID" && "$CURRENT_ACCOUNT_ID" != "$EXPECTED_ACCOUNT_ID" ]]; then
  fail "conta autenticada ($CURRENT_ACCOUNT_ID) difere da conta esperada ($EXPECTED_ACCOUNT_ID)"
fi

aws s3api head-bucket --bucket "$STATE_BUCKET" >/dev/null

echo
echo "ATENCAO: esta operacao destruira o ambiente personal-demo."
echo "Conta AWS : $CURRENT_ACCOUNT_ID"
echo "Regiao dos recursos : $AWS_REGION_VALUE"
echo "Regiao do state     : $STATE_REGION"
echo "State S3  : s3://${STATE_BUCKET}/${STATE_KEY}"
echo

if [[ "$AUTO_APPROVE" == true ]]; then
  [[ -n "$EXPECTED_ACCOUNT_ID" ]] || fail "--auto-approve exige --account-id ou EXPECTED_AWS_ACCOUNT_ID"
else
  CONFIRMATION="destroy ${CURRENT_ACCOUNT_ID} personal-demo"
  read -r -p "Digite '${CONFIRMATION}' para continuar: " ANSWER
  [[ "$ANSWER" == "$CONFIRMATION" ]] || fail "confirmacao incorreta; nenhuma alteracao foi realizada"
fi

# Variaveis obrigatorias precisam existir para carregar a configuracao durante
# o destroy. Os placeholders abaixo nao sao gravados em recursos novos.
export AWS_REGION="$AWS_REGION_VALUE"
export AWS_DEFAULT_REGION="$AWS_REGION_VALUE"
export TF_IN_AUTOMATION=true
export TF_INPUT=false
export TF_VAR_eks_public_access_cidrs="${TF_VAR_eks_public_access_cidrs:-[\"0.0.0.0/0\"]}"
export TF_VAR_auth_db_password="${TF_VAR_auth_db_password:-destroy-only-placeholder-auth}"
export TF_VAR_flags_db_password="${TF_VAR_flags_db_password:-destroy-only-placeholder-flags}"
export TF_VAR_targeting_db_password="${TF_VAR_targeting_db_password:-destroy-only-placeholder-targeting}"
export TF_VAR_auth_master_key="${TF_VAR_auth_master_key:-destroy-only-placeholder-auth-master-key}"
export TF_VAR_evaluation_service_api_key="${TF_VAR_evaluation_service_api_key:-destroy-only-placeholder-evaluation-key}"
export TF_VAR_newrelic_license_key="${TF_VAR_newrelic_license_key:-destroy-only-placeholder-newrelic-license-key}"
export TF_VAR_discord_webhook_url="${TF_VAR_discord_webhook_url:-https://discord.com/api/webhooks/destroy-only/placeholder}"

terraform -chdir="$ENVIRONMENT_DIR" init -reconfigure \
  -backend-config="bucket=${STATE_BUCKET}" \
  -backend-config="key=${STATE_KEY}" \
  -backend-config="region=${STATE_REGION}" \
  -backend-config="use_lockfile=true"

if [[ -z "$(terraform -chdir="$ENVIRONMENT_DIR" state list)" ]]; then
  echo "O state personal-demo ja esta vazio; nao ha recursos para destruir."
  exit 0
fi

DESTROY_PLAN="$(mktemp "${TMPDIR:-/tmp}/togglemaster-personal-demo-destroy.XXXXXX")"
trap 'rm -f -- "${DESTROY_PLAN:-}"' EXIT

terraform -chdir="$ENVIRONMENT_DIR" plan -destroy \
  -var-file="$PROFILE_FILE" \
  -out="$DESTROY_PLAN"
terraform -chdir="$ENVIRONMENT_DIR" apply -auto-approve "$DESTROY_PLAN"

if [[ -n "$(terraform -chdir="$ENVIRONMENT_DIR" state list)" ]]; then
  fail "o Terraform terminou, mas o state ainda possui recursos"
fi

echo "Destruicao concluida. O bucket de state foi preservado para auditoria e reutilizacao."

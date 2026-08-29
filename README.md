# ToggleMaster Infrastructure

Infraestrutura como codigo do ToggleMaster, provisionada com Terraform na AWS. Para respeitar os limites de recursos do AWS Academy, existe um unico ambiente implantavel, `homolog`, que concentra todos os componentes exigidos pelo desafio.

## Recursos provisionados

- VPC, Internet Gateway, duas subnets publicas e duas privadas, tabelas de rotas e NAT Gateway opcional.
- EKS com Managed Node Group nas subnets privadas e add-ons `vpc-cni`, `kube-proxy` e `coredns`.
- Tres instancias RDS PostgreSQL: `auth`, `flags` e `targeting`.
- ElastiCache Redis.
- DynamoDB `ToggleMasterAnalytics-<ambiente>` com capacidade sob demanda.
- SQS de eventos de avaliacao com dead-letter queue.
- Cinco repositorios ECR: auth, flag, targeting, evaluation e analytics.
- ArgoCD instalado no EKS pelo chart Helm oficial e root Application criada pelo
  mesmo `terraform apply` para iniciar a reconciliacao GitOps.

## Estrutura

```text
togglemaster-infrastructure/
├── bootstrap/                 # bucket S3 do backend
├── modules/
│   ├── networking/
│   ├── eks/
│   ├── rds/
│   ├── elasticache/
│   ├── dynamodb/
│   ├── sqs/
│   ├── ecr/
│   └── argocd/
├── environments/
│   └── homolog/                # unico ambiente implantavel
└── .github/workflows/terraform.yml
```

## AWS Academy

Esta configuracao foi desenhada para as restricoes do AWS Academy:

- nenhum recurso `aws_iam_role`, `aws_iam_policy` ou equivalente e criado;
- a `LabRole` existente e recebida em `lab_role_arn`;
- a mesma `LabRole` e usada em `role_arn` do cluster EKS e em `node_role_arn` do Managed Node Group;
- o acesso administrativo inicial ao EKS fica com o principal que cria o cluster;
- `academy_mode` deve permanecer `true` e possui uma guardrail no Terraform.

Antes do apply, confirme que a LabRole possui as permissoes e a trust policy necessarias para EKS e EC2. O AWS Academy pode limitar tipos de instancia, regioes e servicos; ajuste os parametros do ambiente caso a sua turma use limites diferentes.

## 1. Criar o backend

O bootstrap usa state local somente para criar o bucket S3. Escolha um nome globalmente unico:

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars
# edite state_bucket_name
terraform init
terraform plan
terraform apply
```

O bucket possui versionamento, criptografia SSE-S3, bloqueio integral de acesso publico, ownership enforced e uma policy que nega transporte sem TLS. `prevent_destroy` reduz o risco de apagar o state.

O locking usa o arquivo de lock nativo do backend S3 (`use_lockfile = true`), disponivel a partir do Terraform 1.10. Nao e criada tabela DynamoDB para lock.

## 2. Inicializar o ambiente

Copie o exemplo de backend e informe o bucket criado:

```bash
cd environments/homolog
cp backend.hcl.example backend.hcl
# edite o nome do bucket
terraform init -backend-config=backend.hcl
```

A chave do state e fixa no root unico: `togglemaster/homolog/terraform.tfstate`.

## 3. Informar variaveis e credenciais

Credenciais temporarias do AWS Academy devem estar no ambiente:

```bash
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
export AWS_REGION="us-east-1"
```

Variaveis sensiveis nao devem ser commitadas:

```bash
export TF_VAR_lab_role_arn="arn:aws:iam::123456789012:role/LabRole"
export TF_VAR_auth_db_password="..."
export TF_VAR_flags_db_password="..."
export TF_VAR_targeting_db_password="..."
terraform plan
```

Use senhas com pelo menos 16 caracteres. Para reduzir exposicao do endpoint do EKS, configure `eks_public_access_cidrs` com o IP publico da equipe em vez de `0.0.0.0/0`.

## Custos e operacao

O NAT Gateway permite que nodes privados acessem ECR e endpoints externos, mas cobra por hora e por trafego. Em laboratorios onde o custo for impeditivo, desabilite `enable_nat_gateway` somente se fornecer outra rota de saida ou VPC endpoints; sem saida, os nodes podem nao iniciar corretamente.

O ambiente usa uma configuracao economica: um node EKS, instancias RDS `db.t3.micro` sem Multi-AZ, um node Redis `cache.t3.micro` e backups reduzidos. Isso evita duplicar clusters, bancos e repositorios ECR sem remover os componentes obrigatorios. Revise quotas e disponibilidade dos tipos `t3`/`db.t3`/`cache.t3` na conta Academy antes do apply.

## Pipeline GitHub Actions

Em Pull Requests, o workflow executa para o ambiente unico:

1. `terraform fmt -check -recursive`;
2. `terraform init`;
3. `terraform validate`;
4. scan de configuracao com Trivy para achados HIGH/CRITICAL;
5. `terraform plan`.

Nao existe etapa de apply em Pull Requests. Na branch `main`, as validacoes e o plan sao repetidos, e o apply roda no GitHub Environment `homolog`.

Configure no repositorio:

- secrets `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` e `TF_STATE_BUCKET`;
- variable `LAB_ROLE_ARN`;
- variable `EKS_PUBLIC_ACCESS_CIDRS` em formato JSON, por exemplo `["203.0.113.10/32"]`;
- secrets `HOMOLOG_AUTH_DB_PASSWORD`, `HOMOLOG_FLAGS_DB_PASSWORD`, `HOMOLOG_TARGETING_DB_PASSWORD`;
- GitHub Environment chamado `homolog`.

As credenciais do AWS Academy expiram. Atualize os tres secrets AWS antes de executar o pipeline. Pull Requests vindos de forks nao recebem secrets e, portanto, nao conseguem executar `init`/`plan` contra o backend remoto.

## ArgoCD

O modulo `modules/argocd` usa o provider Helm do Terraform. Alem de instalar o
chart `argo-cd`, ele inclui a Application `togglemaster-root` via `extraObjects`;
portanto nao existe um `kubectl apply` manual no bootstrap normal. A root
Application observa `https://github.com/devjean96/togglemaster-gitops.git`, no
path `argocd`, e possui sincronizacao automatica com `prune` e `selfHeal`.

Para desabilitar temporariamente o bootstrap da root Application, defina
`argocd_bootstrap_gitops = false`. Se o repositorio GitOps for privado, configure
as credenciais do repositorio no ArgoCD por um mecanismo declarativo antes do
primeiro sync; nao grave tokens em arquivos `.tfvars`.

Depois do apply, atualize o kubeconfig e obtenha a senha inicial:

```bash
aws eks update-kubeconfig --name togglemaster-homolog-eks --region us-east-1
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

O Service do ArgoCD fica como `ClusterIP`. Use `kubectl port-forward` ou altere conscientemente o tipo de Service antes de expo-lo externamente.

O repositorio ECR usado inicialmente pela pipeline do auth pode ser consultado
com `terraform output -raw auth_ecr_repository_url`. Sua criacao, scan-on-push,
criptografia e politica de tags imutaveis pertencem ao modulo `modules/ecr`; a
pipeline da aplicacao apenas verifica sua existencia e publica imagens.

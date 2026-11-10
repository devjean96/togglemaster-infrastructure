# ToggleMaster Infrastructure

Infraestrutura como codigo do ToggleMaster, provisionada com Terraform na AWS. Para respeitar os limites de recursos do AWS Academy, existe um unico ambiente implantavel, `homolog`, que concentra todos os componentes exigidos pelo desafio.

## Recursos provisionados

- VPC, Internet Gateway, duas subnets publicas e duas privadas, tabelas de rotas e NAT Gateway opcional.
- EKS com Managed Node Group nas subnets privadas e add-ons `vpc-cni`,
  `kube-proxy`, `coredns` e `metrics-server`.
- Tres instancias RDS PostgreSQL: `auth`, `flags` e `targeting`.
- ElastiCache Redis.
- DynamoDB `ToggleMasterAnalytics-<ambiente>` com capacidade sob demanda.
- SQS de eventos de avaliacao com dead-letter queue.
- Cinco repositorios ECR: auth, flag, targeting, evaluation e analytics.
- Quatro Kubernetes Secrets para auth, flag, targeting e evaluation, entregues
  por uma release Helm gerenciada pelo Terraform.
- Ingress NGINX com uma replica e Network Load Balancer publico para acesso aos
  microservicos pelos respectivos prefixos HTTP.
- ArgoCD instalado no EKS pelo chart Helm oficial e root Application criada pelo
  mesmo `terraform apply` para iniciar a reconciliacao GitOps.
- OpenTelemetry Collector em modo gateway, exposto somente por Service
  `ClusterIP` nas portas OTLP 4317/4318 e exportando traces e metricas ao New
  Relic por HTTPS/443.
- Loki monolitico com volume local temporario, gateway `ClusterIP`, retencao
  maxima de sete dias e OpenTelemetry Collector de logs executado como
  DaemonSet.

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
│   ├── workload-secrets/
│   ├── opentelemetry-collector/
│   ├── loki/
│   ├── ingress-nginx/
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

O bootstrap usa state local e cria o bucket S3 de forma idempotente. Por padrao,
o nome e montado automaticamente como
`togglemaster-terraform-state-<ACCOUNT_ID_ATIVO>`:

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

`state_bucket_name` permanece disponivel como override opcional. No AWS
Academy, prefira o valor automatico porque a conta do laboratorio pode mudar
entre sessoes.

No AWS Academy, a SCP bloqueia `s3:GetBucketObjectLockConfiguration`, mas o
resource `aws_s3_bucket` executa essa leitura em todo refresh. Por isso, o
bootstrap cria o bucket via AWS CLI e o trata como externo no Terraform; se o
bucket ja existir e estiver acessivel, ele sera reutilizado. O Terraform ainda
gerencia versionamento, criptografia SSE-S3, bloqueio integral de acesso
publico, ownership enforced e a policy que nega transporte sem TLS. Como o
bucket nao e um resource Terraform, um `terraform destroy` no bootstrap nao o
remove.

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
export TF_VAR_auth_master_key="..."
export TF_VAR_evaluation_service_api_key="..."
export TF_VAR_newrelic_license_key="..."
terraform plan
```

Use senhas com pelo menos 16 caracteres. Para reduzir exposicao do endpoint do EKS, configure `eks_public_access_cidrs` com o IP publico da equipe em vez de `0.0.0.0/0`.

## Custos e operacao

O NAT Gateway permite que nodes privados acessem ECR e endpoints externos, mas cobra por hora e por trafego. Em laboratorios onde o custo for impeditivo, desabilite `enable_nat_gateway` somente se fornecer outra rota de saida ou VPC endpoints; sem saida, os nodes podem nao iniciar corretamente.

O ambiente usa tres nodes EKS `t3.large` em um unico Managed Node Group para
acomodar os microservicos e a stack completa de observabilidade. As instancias
RDS `db.t3.micro` permanecem sem Multi-AZ, o Redis usa um node
`cache.t3.micro` e os backups continuam reduzidos. Revise as quotas, o saldo do
laboratorio e a disponibilidade dos tipos `t3`/`db.t3`/`cache.t3` na conta AWS
Academy antes do apply.

O Ingress NGINX cria um Network Load Balancer, que possui cobranca por hora e
por uso. Restrinja `ingress_load_balancer_source_ranges` ao CIDR publico da
equipe quando nao for necessario acesso de toda a Internet.

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
- variable opcional `LAB_ROLE_ARN`. Sem ela, o workflow consulta o account ID
  autenticado via STS e monta automaticamente
  `arn:aws:iam::<ACCOUNT_ID>:role/LabRole`;
- Environment secret `HOMOLOG_NEW_RELIC_LICENSE_KEY` com a license key de
  ingestao do New Relic;
- variable opcional `EKS_PUBLIC_ACCESS_CIDRS` em formato JSON, por exemplo
  `["203.0.113.10/32"]`. Sem essa variable, a pipeline usa `["0.0.0.0/0"]`
  como bypass para permitir que runners efemeros acessem os providers
  Helm/Kubernetes;
- variable opcional `EKS_HTTPS_EGRESS_CIDRS` em formato JSON. O fallback
  `["0.0.0.0/0"]` permite somente TCP/443 por essa regra;
- variable opcional `INGRESS_LOAD_BALANCER_SOURCE_RANGES` em formato JSON. Use
  `["0.0.0.0/0"]` para acesso publico ou restrinja ao CIDR da equipe;
- Environment secrets `HOMOLOG_AUTH_DB_PASSWORD`,
  `HOMOLOG_FLAGS_DB_PASSWORD`, `HOMOLOG_TARGETING_DB_PASSWORD`,
  `HOMOLOG_AUTH_MASTER_KEY` e `HOMOLOG_EVALUATION_SERVICE_API_KEY`;
- GitHub Environment chamado `homolog`.

Os jobs de plan e apply referenciam o Environment `homolog`, pois ambos precisam
das variaveis sensiveis. Se houver required reviewers, o plan tambem aguardara
aprovacao antes de receber os secrets. As URLs PostgreSQL sao montadas pelo
Terraform com os endpoints RDS e nunca devem ser cadastradas manualmente no Git.

As credenciais do AWS Academy expiram. Atualize os tres secrets AWS antes de executar o pipeline. Pull Requests vindos de forks nao recebem secrets e, portanto, nao conseguem executar `init`/`plan` contra o backend remoto.

## OpenTelemetry Collector e New Relic

O modulo `modules/opentelemetry-collector` instala uma release Helm local no
namespace `observability`. A release cria:

- Secret `newrelic-otlp`, abastecido pela variavel sensivel
  `newrelic_license_key`;
- ConfigMap com receiver OTLP/gRPC e OTLP/HTTP, enriquecimento de metadados
  Kubernetes, limitador de memoria, batch, fila e retry;
- Deployment com uma replica e probes na porta 13133;
- Service `opentelemetry-collector` do tipo `ClusterIP` nas portas OTLP 4317 e
  4318;
- RBAC somente leitura para o processor `k8sattributes`.

Os SDKs dos microservicos devem enviar traces para o endpoint interno retornado
pelo Terraform:

```bash
terraform -chdir=environments/homolog output -raw opentelemetry_otlp_http_endpoint
```

O valor padrao e
`http://opentelemetry-collector.observability.svc.cluster.local:4318`. A chave
do New Relic fica apenas no pod do Collector e nao deve ser adicionada aos
Deployments das aplicacoes.

O modulo EKS adiciona uma regra explicita no cluster security group permitindo
saida TCP/443 aos CIDRs de `eks_https_egress_cidrs`. O padrao e `0.0.0.0/0`
porque os enderecos do endpoint SaaS podem mudar; a regra continua restrita ao
protocolo TCP e a porta 443. A rota efetiva para a Internet depende do NAT
Gateway permanecer habilitado para as subnets privadas.

Essa regra garante a disponibilidade de HTTPS, mas nao remove outras regras de
egress que o proprio EKS possa manter no cluster security group. Uma politica de
saida estritamente limitada a 443 exigiria tambem um security group de nodes
gerenciado por launch template e revisao das dependencias ECR, STS e API do EKS.

Para contas New Relic fora da regiao US, altere `newrelic_otlp_endpoint` para o
endpoint regional correspondente. Depois do apply, valide:

```bash
kubectl -n observability get deployment,pods,service
kubectl -n observability logs deployment/opentelemetry-collector
```

O Collector exporta traces e metricas OTLP ao New Relic. Os logs OTLP
dos SDKs permanecem desativados para evitar duplicidade: os microsservicos
escrevem em `stdout`/`stderr`, e o Collector em DaemonSet coleta os arquivos dos
containers. Prometheus e Grafana permanecem fora deste modulo.

## Loki e coleta de logs

O modulo `modules/loki` instala o chart `grafana-community/loki` fixado na
versao declarada por `loki_chart_version`. Para reduzir custo e complexidade no
AWS Academy, o Loki usa o modo monolitico com uma replica, autenticacao
desativada somente na rede interna do cluster e gateway `ClusterIP`.

O armazenamento usa um volume local `emptyDir` limitado a `20Gi`, e os logs
possuem retencao maxima de `168h` (sete dias). Essa escolha e intencional para o
AWS Academy: a `LabRole` nao possui trust para IRSA/Pod Identity, e o controller
do `aws-ebs-csi-driver` nao recebe credenciais para provisionar volumes. Os logs
sao perdidos se o pod do Loki for removido ou reagendado. Prometheus, Grafana,
dashboards e ServiceMonitors nao sao instalados por esta etapa.

Quando `install_loki=true`, a release do OpenTelemetry tambem cria o DaemonSet
`opentelemetry-collector-logs`, com uma replica em cada node. Cada agente le
`/var/log/pods`, enriquece os registros com namespace, pod, container, node,
`service.name`, `service.version` e ambiente, e envia os logs pelo endpoint
OTLP/HTTP nativo do Loki:

```text
http://loki-gateway.observability.svc.cluster.local/otlp
```

Depois do apply, valide:

```bash
kubectl -n observability get statefulset,deployment,daemonset,pods,service
kubectl -n observability rollout status statefulset/loki
kubectl -n observability rollout status daemonset/opentelemetry-collector-logs
kubectl -n observability logs daemonset/opentelemetry-collector-logs --tail=100
```

Teste a prontidao do Loki a partir do cluster:

```bash
kubectl -n observability port-forward service/loki 3100:3100
curl --fail http://127.0.0.1:3100/ready
```

O endpoint interno para uma futura configuracao do Data Source no Grafana e:

```bash
terraform -chdir=environments/homolog output -raw loki_gateway_endpoint
```

## Excecoes de seguranca do AWS Academy

O scan Trivy continua bloqueando achados `HIGH` e `CRITICAL`. Somente tres
regras possuem bypass inline, limitado ao recurso correspondente e com expiracao
em `2027-08-29`:

- `AWS-0132`: o bucket de state usa SSE-S3 (`AES256`); uma CMK adicionaria custo
  e pode exigir permissoes KMS indisponiveis no laboratorio;
- `AWS-0039`: a criptografia de Secrets do EKS com CMK depende das mesmas
  permissoes KMS;
- `AWS-0040`: o endpoint publico do EKS e necessario para o runner hospedado do
  GitHub instalar o ArgoCD via Terraform. O endpoint privado permanece ativo e
  a autenticacao IAM continua obrigatoria. Quando existir um runner ou IP de
  saida estavel, configure `EKS_PUBLIC_ACCESS_CIDRS` e remova o fallback aberto.

As excecoes devem ser revistas antes da expiracao. Em uma conta AWS sem as
restricoes do Academy, use CMKs para S3/EKS e um runner com conectividade privada
ao endpoint do cluster, removendo os bypasses.

## ArgoCD

O modulo `modules/argocd` usa duas releases do provider Helm. A primeira instala
o chart `argo-cd` e aguarda seus CRDs; a segunda instala o chart local
`bootstrap-chart`, que cria a Application `togglemaster-root`. Essa ordem evita
tentar validar o kind `Application` antes de o CRD existir e nao requer
`kubectl apply` manual. A root Application observa
`https://github.com/devjean96/togglemaster-gitops.git`, no path `argocd`, e
possui sincronizacao automatica com `prune` e `selfHeal`.

O ambiente fixa o Kubernetes em `1.36` e o chart `argo-cd` em `10.4.1`, que
instala o ArgoCD `3.5.2` com schemas do Kubernetes `1.36`. Mantenha essas versoes
compativeis para evitar `ComparisonError` em campos novos da API, como
`Deployment.status.terminatingReplicas`.

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

## Acesso externo aos microservicos

O Terraform instala o chart oficial `ingress-nginx` e cria o Service
`ingress-nginx-controller` como `LoadBalancer`. O NLB encaminha as requisicoes
ao Ingress mantido no repositorio GitOps. Depois do apply, obtenha o hostname:

```bash
terraform -chdir=environments/homolog output -raw ingress_load_balancer_hostname
terraform -chdir=environments/homolog output -raw auth_service_external_url
terraform -chdir=environments/homolog output microservice_external_urls
```

Se o primeiro apply retornar `null`, aguarde o provisionamento do NLB e execute
`terraform refresh` ou consulte diretamente o cluster:

```bash
kubectl -n ingress-nginx get service ingress-nginx-controller
kubectl -n togglemaster-homolog get ingress togglemaster
```

As rotas externas sao `/auth`, `/flags`, `/targeting`, `/evaluate` e
`/analytics`. Por exemplo, o health check de autenticacao fica disponível em
`http://<HOSTNAME_DO_NLB>/auth/health`.

O repositorio ECR usado inicialmente pela pipeline do auth pode ser consultado
com `terraform output -raw auth_ecr_repository_url`. Sua criacao, scan-on-push,
criptografia e politica de tags imutaveis pertencem ao modulo `modules/ecr`; a
pipeline da aplicacao apenas verifica sua existencia e publica imagens.

## Destruir o ambiente e interromper custos

O script abaixo valida a conta AWS autenticada, exige uma confirmacao contendo o
account ID, usa o state remoto e destroi todo o ambiente `homolog`. Os
repositorios ECR desse ambiente sao configurados com `force_delete`, portanto as
imagens tambem sao removidas.

```bash
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."

./scripts/destroy-academy.sh \
  --state-bucket "togglemaster-terraform-state-ACCOUNT_ID" \
  --account-id "ACCOUNT_ID"
```

Por seguranca, o bucket versionado que armazena o state e preservado por padrao.
Depois que todos os recursos tiverem sido destruidos, use
`--delete-state-bucket` para remover tambem todas as versoes do state e o bucket.
Essa opcao e irreversivel. Se o bootstrap for aplicado novamente depois da
exclusao, use `terraform apply -replace=terraform_data.state_bucket` para
executar novamente a etapa de criacao do bucket.

```bash
./scripts/destroy-academy.sh \
  --state-bucket "togglemaster-terraform-state-ACCOUNT_ID" \
  --account-id "ACCOUNT_ID" \
  --delete-state-bucket
```

O script nao procura nem apaga recursos fora do state Terraform. Ao final,
confira o painel de billing do AWS Academy, pois recursos criados manualmente ou
por outras atividades nao pertencem a este projeto.

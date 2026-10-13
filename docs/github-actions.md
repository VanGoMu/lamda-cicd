# Configuración de GitHub Actions

Esta guía configura GitHub para que los workflows puedan desplegar Lambda en AWS mediante
OIDC. No se crean access keys permanentes.

## 1. Requisitos

Necesitas:

- Un repositorio GitHub con Actions habilitado.
- Permiso de administración del repositorio para crear variables y proteger tags.
- AWS CLI autenticada para ejecutar el bootstrap.
- GitHub CLI opcional, autenticada con `gh auth login`.

El bootstrap debe ejecutarse antes de configurar las variables:

```bash
export AWS_REGION=eu-west-1
export GITHUB_OWNER=tu-organizacion
export GITHUB_REPOSITORY=tu-organizacion/lamda-cicd
./scripts/bootstrap.sh
```

El script detecta `GITHUB_ORGANIZATION_ID` y `GITHUB_REPOSITORY_ID` mediante una petición `GET` a
la API REST de GitHub si no los declaras. Necesitas `curl` y `jq`; para un repositorio privado,
define `GITHUB_TOKEN`. También puedes declarar uno o ambos IDs manualmente si quieres evitar la
consulta.

El bootstrap crea un proveedor OIDC, un bucket, un secreto y el role
`lambda-cicd-github-actions`. Si se modifica el trust policy, vuelve a ejecutar el bootstrap.
Los IDs numéricos son necesarios porque GitHub los incluye en el claim `sub` del token OIDC.

## 2. Obtener outputs de AWS

```bash
export BOOTSTRAP_STACK_NAME=lambda-cicd-bootstrap

export ARTIFACT_BUCKET="$(aws cloudformation describe-stacks \
  --region "$AWS_REGION" \
  --stack-name "$BOOTSTRAP_STACK_NAME" \
  --query 'Stacks[0].Outputs[?OutputKey==`ArtifactBucketName`].OutputValue' \
  --output text)"
export SECRET_ARN="$(aws cloudformation describe-stacks \
  --region "$AWS_REGION" \
  --stack-name "$BOOTSTRAP_STACK_NAME" \
  --query 'Stacks[0].Outputs[?OutputKey==`SecretArn`].OutputValue' \
  --output text)"
export AWS_ROLE_ARN="$(aws cloudformation describe-stacks \
  --region "$AWS_REGION" \
  --stack-name "$BOOTSTRAP_STACK_NAME" \
  --query 'Stacks[0].Outputs[?OutputKey==`GitHubRoleArn`].OutputValue' \
  --output text)"

echo "AWS_REGION: $AWS_REGION"
echo "ARTIFACT_BUCKET: $ARTIFACT_BUCKET"
echo "SECRET_ARN: $SECRET_ARN"
echo "AWS_ROLE_ARN: $AWS_ROLE_ARN"
```

`SECRET_ARN` es solo un identificador. Nunca extraigas el valor del secreto para configurarlo
en GitHub.

## 3. Variables del repositorio

En GitHub abre:

```text
Settings → Secrets and variables → Actions → Variables → New repository variable
```

Crea estas variables comunes:

| Nombre | Ejemplo | Obligatoria |
|---|---|:---:|
| `AWS_REGION` | `eu-west-1` | Sí |
| `ARTIFACT_BUCKET` | `lambda-cicd-bootstrap-artifactbucket-abc123` | Sí |
| `SECRET_ARN` | `arn:aws:secretsmanager:...` | Sí |
| `AWS_ROLE_ARN` | `arn:aws:iam::123456789012:role/lambda-cicd-github-actions` | Sí |

No crees `AWS_ACCESS_KEY_ID` ni `AWS_SECRET_ACCESS_KEY`. El action
`aws-actions/configure-aws-credentials` obtiene credenciales temporales con el token OIDC.

## 4. Variables por modo

### Directo

No necesita variables adicionales. Publica con:

```bash
git tag direct-v1.2.3
git push origin direct-v1.2.3
```

Opcionales:

```text
STACK_NAME_DIRECT
FUNCTION_NAME_DIRECT
```

### API Gateway

```text
API_STAGE_NAME=v1
```

Publica con:

```bash
git tag api-v1.2.3
git push origin api-v1.2.3
```

Opcionalmente define:

```text
STACK_NAME_API_GATEWAY
FUNCTION_NAME_API_GATEWAY
```

### Application Load Balancer

Necesita dos subnets de Availability Zones distintas y un Security Group existente:

```text
ALB_SUBNETS=subnet-aaaaaaaa,subnet-bbbbbbbb
ALB_SECURITY_GROUP_ID=sg-aaaaaaaa
```

Publica con:

```bash
git tag alb-v1.2.3
git push origin alb-v1.2.3
```

Opcionalmente define:

```text
STACK_NAME_ALB
FUNCTION_NAME_ALB
```

### Lambda Function URL

Por defecto usa autenticación IAM:

```text
FUNCTION_URL_AUTH_TYPE=AWS_IAM
```

Para una demo pública controlada:

```text
FUNCTION_URL_AUTH_TYPE=NONE
```

Publica con:

```bash
git tag url-v1.2.3
git push origin url-v1.2.3
```

Opcionalmente define:

```text
STACK_NAME_FUNCTION_URL
FUNCTION_NAME_FUNCTION_URL
```

### S3 + EventBridge

La infraestructura EventBridge se crea una sola vez con
`infrastructure/template-s3-eventbridge.yaml`. Las publicaciones posteriores solo suben los
artefactos al bucket:

```bash
git tag event-v1.2.3
git push origin event-v1.2.3
```

La regla escucha `config/*`, por lo que el workflow sube primero el ZIP y después el JSON. La
subida del JSON emite el evento que invoca Lambda.

## 5. Crear variables con GitHub CLI

Desde la raíz del repositorio, con `gh` autenticado:

```bash
gh variable set AWS_REGION --body "$AWS_REGION"
gh variable set ARTIFACT_BUCKET --body "$ARTIFACT_BUCKET"
gh variable set SECRET_ARN --body "$SECRET_ARN"
gh variable set AWS_ROLE_ARN --body "$AWS_ROLE_ARN"
```

Para ALB:

```bash
gh variable set ALB_SUBNETS --body "subnet-aaaaaaaa,subnet-bbbbbbbb"
gh variable set ALB_SECURITY_GROUP_ID --body "sg-aaaaaaaa"
```

Para una Function URL pública de laboratorio:

```bash
gh variable set FUNCTION_URL_AUTH_TYPE --body "NONE"
```

## 6. Proteger tags

Configura reglas de protección o rulesets para impedir que cualquier colaborador publique tags
de despliegue. Protege estos patrones:

```text
direct-v*
api-v*
alb-v*
url-v*
event-v*
```

El trust policy de AWS acepta solo esos cinco patrones y el repositorio configurado en el
bootstrap. GitHub debe exigir revisión para cambios de workflows y de variables.

## 7. Qué ocurre al publicar un tag

1. GitHub inicia únicamente el workflow cuyo prefijo coincide.
2. El job solicita un token OIDC.
3. AWS STS valida `aud` y `sub` contra el trust policy.
4. GitHub asume el role temporal.
5. El workflow construye el ZIP.
6. Sube `code/<version>.zip` y `config/<version>.json` al bucket.
7. CloudFormation despliega el template específico.
8. Se ejecuta el smoke test directo o HTTP según el modo.

## 8. Verificación

En GitHub revisa:

- La pestaña **Actions** y el workflow asociado al tag.
- El paso `Configure AWS credentials with OIDC`.
- El paso de upload a S3.
- El output de CloudFormation.
- El smoke test sin valor secreto.

En AWS revisa los enlaces que imprime la sección de URLs del README.

## 9. Errores frecuentes

### `Not authorized to perform sts:AssumeRoleWithWebIdentity`

Comprueba `AWS_ROLE_ARN`, `GITHUB_OWNER`, `GITHUB_REPOSITORY` y el prefijo del tag. Si el
bootstrap se ejecutó antes de separar los workflows, vuelve a ejecutarlo.

### `AccessDenied` al subir a S3

Comprueba que `ARTIFACT_BUCKET` coincide exactamente con `ArtifactBucketName`, que el tag usa
el workflow correcto y que la subida incluye `--sse AES256`.

### El workflow no aparece

Comprueba que el fichero `deploy-*.yml` está en la rama por defecto y que el tag usa exactamente
`direct-v`, `api-v`, `alb-v`, `url-v` o `event-v` seguido de una versión SemVer.

### ALB falla al crear

Comprueba que `ALB_SUBNETS` contiene dos subnets de Availability Zones distintas y que
`ALB_SECURITY_GROUP_ID` existe en la misma región.

### Function URL devuelve `403`

Es normal con `FUNCTION_URL_AUTH_TYPE=AWS_IAM` si se usa `curl` sin firma SigV4. Usa AWS CLI,
SDK o una herramienta que firme la petición; para una demo temporal usa `NONE` conscientemente.

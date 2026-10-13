# Despliegue con Lambda Function URL

## Cuándo elegirlo

Usa este modo cuando necesites un endpoint HTTPS sencillo directamente sobre Lambda, sin
API Gateway ni ALB. Es el camino HTTP con menos componentes.

## Recursos

- Template: [`template-function-url.yaml`](../infrastructure/template-function-url.yaml)
- Workflow: [`deploy-function-url.yml`](../.github/workflows/deploy-function-url.yml)
- Lambda y execution role.
- Lambda Function URL.
- Permiso público solo cuando `AuthType` sea `NONE`.

## Autenticación

`AWS_IAM` es el valor por defecto y requiere peticiones firmadas con SigV4. `NONE` convierte la
URL en pública; úsalo solo para una demo controlada y nunca para datos sensibles.

## Configuración de GitHub

Variables obligatorias:

```text
AWS_REGION
ARTIFACT_BUCKET
SECRET_ARN
GITHUB_ROLE_ARN
```

Variable opcional:

```text
FUNCTION_URL_AUTH_TYPE=AWS_IAM
```

La stack por defecto se llama `lambda-cicd-function-url`. Se puede cambiar con
`STACK_NAME_FUNCTION_URL`.

## Publicar

```bash
git tag url-v1.2.3
git push origin url-v1.2.3
```

Para una URL pública de laboratorio:

```text
FUNCTION_URL_AUTH_TYPE=NONE
```

El workflow usa `template-function-url.yaml` y publica el endpoint en el output `FunctionUrl`.
Si la autenticación es `AWS_IAM`, el smoke test del workflow usa invocación directa, porque un
`curl` sin firma no sería una prueba válida.

## Probar

Con `NONE`:

```bash
curl \
  -H 'Content-Type: application/json' \
  -d '{"requestContext":{"requestId":"manual-test"}}' \
  "$FUNCTION_URL"
```

Con `AWS_IAM`, usa AWS CLI, SDK o una herramienta que firme SigV4. No desactives IAM solo para
ocultar un error de firma.

## Coste y límites

No se añade API Gateway ni ALB. Se pagan Lambda, requests de Function URL, S3, Secrets Manager
y CloudWatch Logs. Function URL no sustituye routing complejo, usage plans, WAF o authorizers
avanzados de API Gateway.

## Rollback y limpieza

```bash
git tag url-v1.2.2
git push origin url-v1.2.2
```

Elimina la stack `lambda-cicd-function-url` y revisa el acceso público si se utilizó
`AuthType=NONE`. Conserva o elimina los objetos versionados de S3 según tu política de rollback.

# Despliegue directo de Lambda

## Cuándo elegirlo

Usa este modo cuando Lambda sea invocada por otra aplicación AWS, una prueba local, un job o
un servicio que no necesita un endpoint HTTP propio. No crea API Gateway, ALB ni Function URL.
Es el camino con menos recursos de exposición.

## Recursos

- Template: [`template-direct.yaml`](../infrastructure/template-direct.yaml)
- Workflow: [`deploy-direct.yml`](../.github/workflows/deploy-direct.yml)
- Lambda y execution role.
- Un bucket S3 de artefactos compartido con los dos objetos versionados.

El bucket contiene el ZIP y el JSON, pero son artefactos independientes:

```text
code/1.2.3.zip
config/1.2.3.json
```

Por tanto, la respuesta a "solo subir un S3" es: sí, un solo **bucket S3**; no, no un solo
objeto. La configuración no entra en el ZIP.

## Configuración de GitHub

Variables obligatorias:

```text
AWS_REGION
ARTIFACT_BUCKET
SECRET_ARN
GITHUB_ROLE_ARN
```

La stack por defecto se llama `lambda-cicd-direct`. Se puede cambiar con
`STACK_NAME_DIRECT`.

## Publicar

```bash
git tag direct-v1.2.3
git push origin direct-v1.2.3
```

El workflow valida la versión, construye el ZIP, sube código y configuración al mismo bucket y
despliega únicamente `template-direct.yaml`.

## Probar

El workflow invoca la función directamente. También se puede probar después del despliegue:

```bash
AWS_REGION="$AWS_REGION" \
FUNCTION_NAME="lambda-cicd-demo" \
./scripts/smoke-test.sh
```

La invocación recibe un evento JSON sintético y comprueba una respuesta `statusCode` 200 sin
mostrar el secreto.

## Coste y límites

No hay coste de API Gateway, ALB ni Function URL. Se pagan Lambda, CloudWatch Logs, S3 y
Secrets Manager según uso. El role de GitHub sigue necesitando permiso para subir ambos objetos
y desplegar CloudFormation.

## Rollback y limpieza

```bash
git tag direct-v1.2.2
git push origin direct-v1.2.2
```

Para limpiar, elimina la stack `lambda-cicd-direct` y revisa manualmente las versiones del
bucket y el secreto. Conserva la versión activa hasta confirmar el rollback.

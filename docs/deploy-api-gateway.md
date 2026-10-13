# Despliegue con API Gateway

## Cuándo elegirlo

Usa este modo cuando necesites un endpoint HTTP con routing, stages, métricas y una evolución
posterior hacia authorizers, throttling o dominios personalizados.

## Recursos

- Template: [`template-api-gateway.yaml`](../infrastructure/template-api-gateway.yaml)
- Workflow: [`deploy-api-gateway.yml`](../.github/workflows/deploy-api-gateway.yml)
- Lambda y execution role.
- API Gateway REST regional.
- Método `ANY /` con integración Lambda proxy.
- Permiso de invocación de API Gateway sobre la Lambda.

El template no crea el bucket ni el secreto; los recibe como parámetros comunes.

## Configuración de GitHub

Variables obligatorias:

```text
AWS_REGION
ARTIFACT_BUCKET
SECRET_ARN
AWS_ROLE_ARN
```

Variable opcional:

```text
API_STAGE_NAME=v1
```

La stack por defecto se llama `lambda-cicd-api-gateway`. Se puede cambiar con
`STACK_NAME_API_GATEWAY`.

## Publicar

```bash
git tag api-v1.2.3
git push origin api-v1.2.3
```

El workflow usa `template-api-gateway.yaml`, sube los dos artefactos al bucket común y publica
la URL del stage en el output `ApiGatewayUrl`.

## Probar

El smoke test usa la URL del output:

```bash
curl -X POST \
  -H 'Content-Type: application/json' \
  -d '{"requestContext":{"requestId":"manual-test"}}' \
  "$API_GATEWAY_URL"
```

La ruta está configurada sin autorización para mantener el ejemplo ejecutable. Antes de
publicar datos reales, añade un authorizer, WAF y las restricciones de throttling necesarias.

## Coste y límites

Se paga API Gateway por requests y Lambda por ejecución. La API es regional y el ejemplo solo
crea la ruta raíz. Routing avanzado, custom domain, authorizer y WAF son ampliaciones separadas.

## Rollback y limpieza

```bash
git tag api-v1.2.2
git push origin api-v1.2.2
```

Elimina la stack `lambda-cicd-api-gateway` cuando ya no se necesite y revisa las versiones de
los objetos S3 antes de aplicar lifecycle o borrado.

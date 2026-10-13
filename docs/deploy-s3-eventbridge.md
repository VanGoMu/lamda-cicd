# Despliegue orientado a eventos con S3 y EventBridge

## Qué hace este modo

Este modo separa la infraestructura permanente de la publicación de artefactos:

```text
GitHub Actions
    |
    | code/<version>.zip
    v
S3
    |
    | config/<version>.json
    v
EventBridge
    |
    v
Lambda
```

El workflow no ejecuta `cloudformation deploy` en cada publicación. Sube primero el ZIP y
después el JSON. La regla EventBridge escucha únicamente el evento `Object Created` para
`config/*`; por tanto, la segunda subida es la que dispara la Lambda cuando los dos artefactos
ya están en S3.

## Inicialización única

La stack event-driven debe crearse una vez con el template específico. El ZIP inicial debe
existir antes de crear la función:

```bash
VERSION=1.0.0
./scripts/package.sh "$VERSION"
aws s3 cp "build/lambda-${VERSION}.zip" \
  "s3://${ARTIFACT_BUCKET}/code/${VERSION}.zip" --sse AES256
./scripts/upload-config.sh "$VERSION"

aws cloudformation deploy \
  --region "$AWS_REGION" \
  --stack-name lambda-cicd-s3-eventbridge \
  --template-file infrastructure/template-s3-eventbridge.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    CodeS3Bucket="$ARTIFACT_BUCKET" \
    CodeS3Key="code/${VERSION}.zip" \
    ConfigS3Bucket="$ARTIFACT_BUCKET" \
    ConfigS3Key="config/${VERSION}.json" \
    SecretArn="$SECRET_ARN"
```

La subida de `config/1.0.0.json` puede producir un primer evento antes de que la regla exista;
la Lambda se puede invocar después con una nueva versión de configuración para verificarla.

## Configuración de GitHub

Variables obligatorias:

```text
AWS_REGION
ARTIFACT_BUCKET
SECRET_ARN
AWS_ROLE_ARN
```

Publicar una versión:

```bash
git tag event-v1.2.3
git push origin event-v1.2.3
```

El workflow solo construye y sube el ZIP y el JSON. No actualiza el código de la función con
CloudFormation: EventBridge invoca la función que ya existe.

## Punto importante sobre el código

EventBridge invoca Lambda; no cambia automáticamente el deployment package de Lambda. Si cambia
el código Python, hay que actualizar el `CodeS3Key` de la stack event-driven o ejecutar un
proceso adicional de actualización de código. Si solo cambia la configuración, este flujo es
completo: subir el nuevo JSON dispara la Lambda con la configuración de esa versión.

La Lambda obtiene `bucket` y `key` del evento EventBridge, en lugar de usar únicamente los
valores fijos de sus variables de entorno.

## Permisos

- S3 publica eventos en EventBridge.
- EventBridge tiene permiso para invocar la Lambda.
- Lambda puede leer `config/*` y el ARN concreto de Secrets Manager.
- GitHub solo puede subir `code/*` y `config/*`.

## Verificación

Comprueba la regla y la función:

```bash
aws events list-rules --name-prefix lambda-cicd-eventbridge
aws lambda get-function --function-name lambda-cicd-eventbridge
aws logs tail /aws/lambda/lambda-cicd-eventbridge --since 10m
```

El resultado del workflow confirma el orden de subida. El evento es asíncrono, por lo que el
log puede aparecer unos segundos después de que termine GitHub Actions.

## Coste y limpieza

Se paga S3, EventBridge por eventos, Lambda, Secrets Manager y CloudWatch Logs. No se crea API
Gateway, ALB ni Function URL. Para limpiar, elimina la stack
`lambda-cicd-s3-eventbridge` y revisa las versiones conservadas del bucket.

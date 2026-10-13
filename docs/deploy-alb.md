# Despliegue con Application Load Balancer

## Cuándo elegirlo

Usa este modo cuando la Lambda deba integrarse en una arquitectura HTTP que ya utiliza ALB,
listeners, reglas de routing o targets compartidos. ALB invoca Lambda mediante un target group
de tipo `lambda`.

## Prerrequisitos de red

Debes proporcionar:

- Dos subnets en Availability Zones distintas.
- Un Security Group existente para el ALB.
- Reglas del Security Group que permitan el tráfico esperado en el puerto 80.

La plantilla no crea VPC, subnets ni Security Group. Por defecto el ALB es `internet-facing`;
para una aplicación privada cambia `Scheme` a `internal` en el template antes de desplegar.

## Recursos

- Template: [`template-alb.yaml`](../infrastructure/template-alb.yaml)
- Workflow: [`deploy-alb.yml`](../.github/workflows/deploy-alb.yml)
- Lambda y execution role.
- Application Load Balancer.
- Target group con `TargetType: lambda`.
- Listener HTTP en puerto 80.
- Permiso de invocación para Elastic Load Balancing.

## Configuración de GitHub

Variables obligatorias:

```text
AWS_REGION
ARTIFACT_BUCKET
SECRET_ARN
AWS_ROLE_ARN
ALB_SUBNETS=subnet-aaa,subnet-bbb
ALB_SECURITY_GROUP_ID=sg-aaa
```

La stack por defecto se llama `lambda-cicd-alb`. Se puede cambiar con `STACK_NAME_ALB`.

## Publicar

```bash
git tag alb-v1.2.3
git push origin alb-v1.2.3
```

El workflow valida que las variables de red no estén vacías, usa el template exclusivo del ALB
y publica el endpoint en el output `AlbUrl`.

## Probar

```bash
curl \
  -H 'Content-Type: application/json' \
  -d '{"requestContext":{"requestId":"manual-test"}}' \
  "$ALB_URL"
```

La respuesta debe conservar el formato compatible con la integración Lambda de ALB.

## Coste y seguridad

El ALB tiene coste por hora y por capacidad procesada, aunque el tráfico sea bajo. También se
pagan Lambda, S3, Secrets Manager y logs. El template no configura autenticación de aplicación;
usa HTTPS mediante un listener adicional, un certificado ACM y reglas de seguridad antes de
exponer datos reales.

## Rollback y limpieza

```bash
git tag alb-v1.2.2
git push origin alb-v1.2.2
```

Elimina la stack `lambda-cicd-alb` para retirar ALB, listener y target group. No borres las
subnets ni el Security Group porque son recursos externos al stack.

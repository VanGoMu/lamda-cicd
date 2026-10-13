# Prompt de construcción · Lambda CI/CD con GitHub Actions

## Rol

Actúa como un ingeniero senior de AWS, Python, seguridad cloud y GitHub Actions. Debes
construir un repositorio público, pequeño pero completo, que demuestre un flujo real de
integración continua y despliegue de una función AWS Lambda desde GitHub Actions.

Trabaja directamente en:

`/home/epicuro/Desktop/AWS/repositories/lamda-cicd`

El repositorio debe ser autocontenido y publicable en GitHub. No hagas referencias a
contextos externos, materiales previos ni nombres propios de otros repositorios si no son
necesarios para explicar esta solución.

## Objetivo funcional

Construye una función Lambda de ejemplo en Python que:

1. Reciba un evento sencillo de API Gateway o un evento directo de prueba.
2. Lea configuración no sensible desde un objeto JSON situado en Amazon S3.
3. Lea un secreto desde AWS Secrets Manager mediante el SDK de Python.
4. Devuelva una respuesta JSON útil y fácil de probar.
5. Tenga logs suficientes para diagnosticar errores sin imprimir el secreto.

El flujo de despliegue debe distinguir explícitamente estos artefactos:

- **Artefacto de código**: ZIP con la función y sus dependencias Python, subido a un
  bucket S3 de artefactos.
- **Artefacto de configuración**: fichero JSON independiente, subido a S3 en una ruta
  versionada. Nunca debe entrar en el ZIP de la Lambda.
- **Secreto**: valor almacenado en Secrets Manager. Nunca debe aparecer en el repositorio,
  en el ZIP, en los logs, en los outputs de CloudFormation ni en variables de GitHub Actions.

## Flujo GitHub Actions

Implementa una CI breve y clara para Python que se ejecute en pull requests y pushes a la
rama principal. Debe incluir, como mínimo:

- versión de Python fijada o declarada de forma explícita;
- instalación reproducible de dependencias;
- `ruff check` o equivalente para lint;
- `pytest` con cobertura razonable de la lógica de la Lambda;
- validación sintáctica de la plantilla de infraestructura;
- comprobación de que el paquete de despliegue se puede construir sin incluir el fichero de
  configuración ni secretos.

Implementa un workflow de despliegue separado que:

- se dispare únicamente cuando se publique un tag con formato SemVer, por ejemplo
  `v1.2.3`;
- extraiga la versión desde el tag y la use en los nombres o metadatos del despliegue;
- utilice autenticación OIDC de GitHub Actions hacia AWS mediante
  `aws-actions/configure-aws-credentials`;
- no use access keys estáticas guardadas como secrets de GitHub;
- limite `permissions` a `contents: read` e `id-token: write`;
- construya el ZIP del código;
- suba el ZIP a S3 con una clave que contenga la versión del tag;
- suba el fichero de configuración a una clave S3 distinta y también versionada;
- despliegue o actualice la Lambda mediante CloudFormation o AWS SAM;
- pase a la plantilla la ubicación del artefacto de código y la ubicación del artefacto de
  configuración;
- espere a que termine el despliegue;
- ejecute un smoke test seguro que no revele el secreto;
- deje claro cómo hacer rollback desplegando de nuevo un tag anterior.

El workflow no debe crear automáticamente el proveedor OIDC, el rol IAM, el bucket de
artefactos ni el secreto. Incluye una preparación explícita y reproducible de esos recursos,
preferiblemente mediante una plantilla de infraestructura separada o scripts AWS CLI
idempotentes. El usuario debe poder ejecutarla una vez antes de activar el workflow.

## Seguridad y permisos

Diseña la solución con mínimo privilegio:

- rol IAM de GitHub Actions separado del rol de ejecución de Lambda;
- trust policy del rol de GitHub restringida al repositorio concreto y, cuando corresponda,
  a la rama o patrón de tags esperado;
- permisos del rol de GitHub limitados a leer el repositorio, subir los dos artefactos,
  desplegar la stack y consultar su estado;
- permisos de Lambda limitados a `s3:GetObject` únicamente para el prefijo de configuración
  y a `secretsmanager:GetSecretValue` únicamente para el ARN del secreto;
- cifrado de los buckets con SSE-S3 o SSE-KMS, explicando la elección;
- bloqueo de acceso público en S3;
- no usar `*` en acciones o recursos cuando se pueda declarar el ARN concreto;
- no incluir credenciales en ficheros `.env`, fixtures, snapshots, logs ni documentación;
- añadir `.gitignore` para secretos locales, caches, ZIPs y artefactos generados.

Si algún permiso debe ser más amplio por una limitación real de CloudFormation o del servicio,
documenta el motivo y separa ese caso de los permisos de ejecución de la Lambda.

## Estructura esperada

Adapta la estructura si mejora la solución, pero conserva responsabilidades separadas y una
organización fácil de leer:

```text
lamda-cicd/
├── .github/
│   └── workflows/
│       ├── ci.yml
│       └── deploy.yml
├── src/
│   └── app/
│       ├── __init__.py
│       ├── handler.py
│       ├── config.py
│       └── secrets.py
├── tests/
│   ├── test_handler.py
│   ├── test_config.py
│   └── fixtures/
├── infrastructure/
│   ├── template.yaml
│   └── bootstrap.yaml
├── config/
│   └── example.json
├── scripts/
│   ├── build.sh
│   ├── package.sh
│   ├── upload-config.sh
│   ├── bootstrap.sh
│   └── smoke-test.sh
├── requirements.txt
├── requirements-dev.txt
├── pyproject.toml
├── Makefile
├── README.md
├── SECURITY.md
└── .gitignore
```

El nombre de la carpeta raíz existente contiene `lamda-cicd`; respétalo para esta tarea, pero
usa `lambda` correctamente en los nombres de recursos, documentación, workflows y código.

## Diseño de la aplicación

La Lambda debe ser deliberadamente sencilla, pero no trivial:

- `handler.py` coordina la petición y devuelve respuestas HTTP compatibles con API Gateway;
- `config.py` obtiene el objeto de configuración desde S3 y valida su forma;
- `secrets.py` obtiene el secreto desde Secrets Manager y devuelve solo los campos necesarios
  para la lógica de ejemplo;
- permite inyectar clientes o usar `botocore.stub.Stubber` para que los tests no necesiten AWS;
- diferencia errores de configuración, errores de secreto y errores inesperados;
- no hace una llamada a S3 ni a Secrets Manager en cada test si puede aislarse mediante
  dependencias inyectables;
- usa variables de entorno para bucket, key, región y nombre o ARN del secreto;
- no usa valores sensibles como valores por defecto.

Incluye tests para el camino correcto y para, al menos, configuración ausente o inválida,
secreto ausente y error de dependencia. Los tests deben comprobar también que las respuestas y
los logs no contienen el valor secreto.

## Infraestructura

Usa AWS SAM con CloudFormation, o CloudFormation puro si existe una razón clara. La plantilla
debe declarar como mínimo:

- función Lambda Python;
- rol de ejecución;
- bucket o referencia al bucket de artefactos;
- permisos de lectura del objeto de configuración;
- permiso de lectura del secreto;
- variables de entorno no sensibles;
- parámetros para `CodeS3Bucket`, `CodeS3Key`, `ConfigS3Bucket`, `ConfigS3Key` y
  `SecretArn`;
- outputs con el nombre de la función, ARN y ubicación de configuración.

No incrustes el contenido de `config/example.json` en la plantilla ni en el código de la
Lambda. El despliegue debe poder cambiar la configuración subiendo una nueva versión del
objeto y actualizando el parámetro `ConfigS3Key`, sin reconstruir el ZIP de la función.

Incluye una política de retención y versionado de objetos coherente con el rollback. Explica
qué ocurre con las versiones antiguas y cómo limpiarlas sin borrar accidentalmente la versión
activa.

## Documentación pública

Escribe un `README.md` conciso pero ejecutable, en español con los nombres técnicos de AWS en
inglés. Debe contener:

1. objetivo y arquitectura;
2. diagrama Mermaid del flujo de CI/CD;
3. árbol de directorios;
4. prerrequisitos locales;
5. configuración inicial de AWS;
6. creación del proveedor OIDC y del rol de GitHub, o referencia clara a la plantilla que lo
   hace;
7. creación del bucket y del secreto;
8. formato del JSON de configuración;
9. comandos locales para lint, tests y empaquetado;
10. cómo publicar un tag y qué ejecuta cada workflow;
11. cómo probar la Lambda sin exponer el secreto;
12. rollback a un tag anterior;
13. limpieza de recursos;
14. límites, decisiones y posibles mejoras.

Añade `SECURITY.md` con reglas para reportar secretos expuestos, rotar el secreto y revocar el
rol OIDC. Añade una sección de troubleshooting para errores frecuentes de IAM, S3, Secrets
Manager, CloudFormation y GitHub OIDC.

## Calidad y restricciones

- Código Python con type hints donde aporten claridad.
- Formato de 100 caracteres como máximo en código y workflows cuando sea razonable.
- Bash con `#!/usr/bin/env bash`, `set -euo pipefail`, comillas y comprobación de requisitos.
- Scripts idempotentes y sin secretos hardcodeados.
- No usar heredocs para JSON o YAML si una plantilla versionada resulta más legible.
- No modificar archivos fuera de `/home/epicuro/Desktop/AWS/repositories/lamda-cicd`.
- No instalar herramientas globalmente.
- No ejecutar despliegues reales en AWS durante la construcción ni asumir que existen credenciales.
- Los comandos que puedan generar coste deben estar identificados y requerir una acción
  explícita del usuario.
- No añadir dependencias innecesarias.
- No crear una aplicación compleja: el valor está en la separación de artefactos, el flujo de
  tags, la seguridad y la reproducibilidad.

## Forma de trabajo

Antes de escribir código:

1. inspecciona el directorio y conserva cualquier cambio existente;
2. presenta un plan corto con la estructura y las decisiones principales;
3. señala cualquier ambigüedad que impida una implementación segura.

Después, implementa el repositorio completo. Valida sin AWS:

```bash
python -m pytest
ruff check .
python -m compileall src tests
bash -n scripts/*.sh
```

Si están disponibles, ejecuta también `sam validate --lint` y una comprobación de que el ZIP
no contiene `config/`, `.env`, secretos ni artefactos de tests. No marques una validación como
exitosa si la herramienta no está instalada: indícalo claramente.

Al finalizar, muestra:

- archivos creados o modificados;
- comandos de validación ejecutados y su resultado;
- pasos manuales necesarios en AWS y GitHub;
- riesgos residuales y decisiones que el usuario debe revisar antes de publicar el repositorio.
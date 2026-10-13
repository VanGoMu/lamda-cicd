# Seguridad

## Reportar un secreto expuesto

No abras una issue pública con el valor. Notifica de forma privada al mantenedor y proporciona
solo la ruta, el commit, el workflow y la hora aproximada. El valor expuesto debe considerarse
comprometido inmediatamente.

## Respuesta y rotación

1. Deshabilita o elimina el secreto comprometido en Secrets Manager.
2. Genera un valor nuevo y actualiza el secreto fuera del repositorio.
3. Revisa CloudTrail y CloudWatch Logs en busca de accesos anómalos.
4. Busca el valor en el historial y revoca cualquier credencial asociada.
5. No reutilices el secreto ni lo añadas a fixtures, snapshots, outputs o documentación.

## Revocar GitHub OIDC

Para cortar despliegues, revoca temporalmente el role `lambda-cicd-github-actions` o elimina su
trust policy. Si el repositorio deja de existir, elimina también el proveedor OIDC solo después
de confirmar que ningún otro repositorio de la cuenta lo utiliza.

El role de GitHub y el role de ejecución de Lambda son identidades distintas y deben revisarse
por separado.

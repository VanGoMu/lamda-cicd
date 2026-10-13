"""Acceso aislado a Secrets Manager."""

from __future__ import annotations

import json
from typing import Any, Mapping


class SecretError(Exception):
    """Error esperado al obtener o validar el secreto."""


def load_secret_metadata(secrets_client: Any, secret_arn: str) -> dict[str, bool]:
    """Comprueba el secreto sin devolver ni registrar su valor."""
    try:
        response = secrets_client.get_secret_value(SecretId=secret_arn)
        secret_string = response.get("SecretString")
        if not secret_string:
            raise SecretError("el secreto no contiene SecretString")
        payload = json.loads(secret_string)
    except SecretError:
        raise
    except (KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
        raise SecretError("el secreto no tiene un JSON válido") from exc
    except Exception as exc:
        raise SecretError("no se pudo leer el secreto") from exc

    if not isinstance(payload, Mapping) or not payload:
        raise SecretError("el secreto está vacío o no es un objeto")

    return {"available": True}

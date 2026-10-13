"""Carga y valida configuración no sensible desde S3."""

from __future__ import annotations

import json
from typing import Any, Mapping


class ConfigurationError(Exception):
    """Error esperado al cargar o validar la configuración."""


def load_config(s3_client: Any, bucket: str, key: str) -> dict[str, str]:
    """Obtiene el JSON de S3 y devuelve solo los campos permitidos."""
    try:
        response = s3_client.get_object(Bucket=bucket, Key=key)
        raw_body = response["Body"].read()
        document = json.loads(raw_body)
    except (KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
        raise ConfigurationError("la configuración no es un JSON válido") from exc
    except Exception as exc:  # boto3 exceptions varían según el cliente inyectado.
        raise ConfigurationError("no se pudo leer la configuración desde S3") from exc

    if not isinstance(document, Mapping):
        raise ConfigurationError("la configuración debe ser un objeto JSON")

    required = ("application_name", "environment", "message")
    if any(not isinstance(document.get(field), str) or not document[field] for field in required):
        raise ConfigurationError("faltan campos de configuración obligatorios")

    return {field: document[field] for field in required}

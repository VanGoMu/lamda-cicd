"""Entrada de la Lambda y respuesta compatible con API Gateway."""

from __future__ import annotations

import json
import logging
import os
from typing import Any

from app.config import ConfigurationError, load_config
from app.secrets import SecretError, load_secret_metadata

LOGGER = logging.getLogger(__name__)
LOGGER.setLevel(logging.INFO)


def _configuration_location(event: dict[str, Any]) -> tuple[str, str]:
    """Uses an S3 EventBridge object location when the event provides one."""
    detail = event.get("detail", {})
    bucket = detail.get("bucket", {}).get("name")
    key = detail.get("object", {}).get("key")
    if bucket and key:
        return bucket, key
    return os.environ["CONFIG_BUCKET"], os.environ["CONFIG_KEY"]


def lambda_handler(
    event: dict[str, Any],
    context: Any,
    *,
    s3_client: Any | None = None,
    secrets_client: Any | None = None,
) -> dict[str, Any]:
    """Procesa un evento y nunca incluye el valor secreto en la respuesta o los logs."""
    del context
    try:
        if s3_client is None or secrets_client is None:
            import boto3

            s3_client = s3_client or boto3.client("s3")
            secrets_client = secrets_client or boto3.client("secretsmanager")

        config_bucket, config_key = _configuration_location(event)
        config = load_config(s3_client, config_bucket, config_key)
        secret_metadata = load_secret_metadata(secrets_client, os.environ["SECRET_ARN"])
        LOGGER.info("Petición procesada para application=%s", config["application_name"])
        body = {
            "ok": True,
            "application": config["application_name"],
            "environment": config["environment"],
            "message": config["message"],
            "secret_available": secret_metadata["available"],
            "request_id": event.get("requestContext", {}).get("requestId"),
        }
        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(body),
        }
    except ConfigurationError as exc:
        LOGGER.error("Error de configuración: %s", exc)
        return _error_response(500, "configuration_error")
    except SecretError as exc:
        LOGGER.error("Error de secreto: %s", exc)
        return _error_response(500, "secret_error")
    except KeyError as exc:
        LOGGER.error("Falta una variable de entorno requerida: %s", exc)
        return _error_response(500, "environment_error")
    except Exception:
        LOGGER.exception("Error inesperado procesando la petición")
        return _error_response(500, "internal_error")


def _error_response(status_code: int, error_code: str) -> dict[str, Any]:
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"ok": False, "error": error_code}),
    }


handler = lambda_handler

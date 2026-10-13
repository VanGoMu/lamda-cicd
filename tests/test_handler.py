import json
import logging

from app.handler import lambda_handler


class Body:
    def read(self):
        return b'{"application_name":"demo","environment":"test","message":"hello"}'


class S3Client:
    def get_object(self, **kwargs):
        return {"Body": Body()}


class SecretsClient:
    def get_secret_value(self, **kwargs):
        return {"SecretString": '{"token":"do-not-leak"}'}


def test_handler_returns_safe_success(monkeypatch, caplog):
    monkeypatch.setenv("CONFIG_BUCKET", "bucket")
    monkeypatch.setenv("CONFIG_KEY", "config/v1.json")
    monkeypatch.setenv("SECRET_ARN", "arn:aws:secretsmanager:region:account:secret:name")

    with caplog.at_level(logging.INFO):
        response = lambda_handler(
            {"requestContext": {"requestId": "request-1"}},
            None,
            s3_client=S3Client(),
            secrets_client=SecretsClient(),
        )

    body = json.loads(response["body"])
    assert response["statusCode"] == 200
    assert body["secret_available"] is True
    assert "do-not-leak" not in response["body"]
    assert "do-not-leak" not in caplog.text


def test_handler_hides_secret_error(monkeypatch):
    monkeypatch.setenv("CONFIG_BUCKET", "bucket")
    monkeypatch.setenv("CONFIG_KEY", "config/v1.json")
    monkeypatch.setenv("SECRET_ARN", "arn:test")

    response = lambda_handler(
        {},
        None,
        s3_client=S3Client(),
        secrets_client=type("BrokenSecrets", (), {"get_secret_value": lambda self, **kwargs: {}})(),
    )

    assert response["statusCode"] == 500
    assert json.loads(response["body"]) == {"ok": False, "error": "secret_error"}


def test_handler_accepts_api_gateway_event(monkeypatch):
    monkeypatch.setenv("CONFIG_BUCKET", "bucket")
    monkeypatch.setenv("CONFIG_KEY", "config/v1.json")
    monkeypatch.setenv("SECRET_ARN", "arn:test")

    response = lambda_handler(
        {"requestContext": {"requestId": "api-request"}, "httpMethod": "GET"},
        None,
        s3_client=S3Client(),
        secrets_client=SecretsClient(),
    )

    assert response["statusCode"] == 200
    assert json.loads(response["body"])["request_id"] == "api-request"

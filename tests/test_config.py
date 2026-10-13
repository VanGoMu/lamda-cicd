import json

import pytest

from app.config import ConfigurationError, load_config


class Body:
    def __init__(self, value: bytes):
        self.value = value

    def read(self):
        return self.value


class S3Client:
    def __init__(self, value):
        self.value = value

    def get_object(self, **kwargs):
        return {"Body": Body(self.value)}


def test_load_config_returns_allowed_fields():
    document = {
        "application_name": "demo",
        "environment": "test",
        "message": "hi",
        "extra": "x",
    }
    client = S3Client(json.dumps(document).encode())

    result = load_config(client, "bucket", "config/v1.json")

    assert result == {"application_name": "demo", "environment": "test", "message": "hi"}


@pytest.mark.parametrize("value", [b"not-json", b"[]", b'{"environment":"test"}'])
def test_load_config_rejects_invalid_documents(value):
    with pytest.raises(ConfigurationError):
        load_config(S3Client(value), "bucket", "key")

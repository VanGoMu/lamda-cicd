import json

import pytest

from app.secrets import SecretError, load_secret_metadata


class SecretsClient:
    def __init__(self, value):
        self.value = value

    def get_secret_value(self, **kwargs):
        return {"SecretString": self.value}


def test_secret_returns_metadata_without_value():
    secret = "super-secret-value"

    result = load_secret_metadata(SecretsClient(json.dumps({"token": secret})), "arn:test")

    assert result == {"available": True}
    assert secret not in str(result)


@pytest.mark.parametrize("value", ["", "not-json", "{}"])
def test_secret_rejects_missing_or_invalid_value(value):
    with pytest.raises(SecretError):
        load_secret_metadata(SecretsClient(value), "arn:test")

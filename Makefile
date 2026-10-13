.PHONY: install lint test validate package

install:
	python -m pip install -r requirements-dev.txt

lint:
	ruff check .

test:
	python -m pytest

validate:
	python -m compileall src tests
	sam validate --lint --template-file infrastructure/template.yaml

package:
	./scripts/package.sh "$${VERSION:-local}"

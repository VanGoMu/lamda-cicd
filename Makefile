.PHONY: install lint test validate package

install:
	python -m pip install -r requirements-dev.txt

lint:
	ruff check .

test:
	python -m pytest

validate:
	python -m compileall src tests
	for template in infrastructure/template-*.yaml; do \
		sam validate --lint --template-file "$$template"; \
	done

package:
	./scripts/package.sh "$${VERSION:-local}"

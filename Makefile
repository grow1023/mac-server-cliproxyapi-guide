.DEFAULT_GOAL := test
.PHONY: test check

test: ## run repository checks (shellcheck, check-proxy stub tests, docs, privacy)
	bash tests/run.sh

check: ## check a running proxy: make check PROXY_URL=http://<server>:8317 PROXY_KEY=<client-key>
	bash scripts/check-proxy.sh

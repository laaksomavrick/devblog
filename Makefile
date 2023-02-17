.PHONY: run
run:
	@npx gatsby develop

.PHONY: build
build:
	@npx gatsby build

.PHONY: run-build
run-build:
	@npx gatsby serve

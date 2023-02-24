.PHONY: run
run:
	@npx gatsby develop

.PHONY: build
build:
	@npx gatsby build
  
.PHONY: run-build
run-build:
	@npx gatsby serve

.PHONY: build-staging
build-staging:
	@GATSBY_ACTIVE_ENV=development npx gatsby build


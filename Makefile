REDIS_CONTAINER := smashing-redis
THIN_BINARY := $(shell bundle show thin)/bin/thin

NO_COLOR=\x1b[0m
OK_COLOR=\x1b[32;01m
ERROR_COLOR=\x1b[31;01m
WARN_COLOR=\x1b[33;01m

.PHONY: deps
deps:
	@bundle install

.PHONY: deps-dev
deps-dev:
	@bundle install --with development

.PHONY: redis
redis:
	@-docker stop $(REDIS_CONTAINER)
	@-docker rm $(REDIS_CONTAINER)
	@echo "$(OK_COLOR)Starting redis container$(NO_COLOR)"
	@docker run --name $(REDIS_CONTAINER) -p 6379:6379 -d redis

.PHONY: start
start: deps redis
	smashing start

.PHONY: debug
debug: deps-dev redis
	@echo "$(OK_COLOR)Attach rdebug-ide to port 1234 in VSCode and load http://localhost:3030$(NO_COLOR)"
	rdebug-ide --port 1234 --dispatcher-port 26162 --host 0.0.0.0 -- ${THIN_BINARY}  -R config.ru start -p 3030

.PHONY: test
test: deps-dev
	@rspec

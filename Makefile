COMPOSE := $(shell command -v podman-compose 2>/dev/null || command -v docker 2>/dev/null)
COMPOSE_CMD := $(if $(filter %podman-compose,$(COMPOSE)),podman-compose,docker compose)

.PHONY: dev dev-ui down down-ui

dev: ## Start graph databases (Neo4j + Memgraph)
	$(COMPOSE_CMD) up -d

dev-ui: ## Start graph databases + Memgraph Lab UI
	$(COMPOSE_CMD) up -d
	$(COMPOSE_CMD) -f docker-compose.lab.yml up -d

down: ## Stop graph databases
	$(COMPOSE_CMD) down

down-ui: ## Stop graph databases + Memgraph Lab UI
	$(COMPOSE_CMD) -f docker-compose.lab.yml down
	$(COMPOSE_CMD) down

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help

.PHONY: help build up down logs shell clean status test-db create-namespace

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build the Temporal Docker image
	@echo "Building Temporal Docker image..."
	docker-compose build

up: ## Start all services
	@echo "Starting Temporal services..."
	docker-compose up -d
	@echo ""
	@echo "Waiting for services to be healthy..."
	@sleep 5
	@$(MAKE) status
	@echo ""
	@echo "Temporal is starting up. This may take 1-2 minutes."
	@echo "Access the Web UI at: http://localhost:8080"

down: ## Stop all services
	@echo "Stopping Temporal services..."
	docker-compose down

logs: ## Show logs from all services
	docker-compose logs -f

logs-temporal: ## Show logs from Temporal server only
	docker-compose logs -f temporal

logs-db: ## Show logs from PostgreSQL only
	docker-compose logs -f postgresql

status: ## Show status of all services
	@echo "Service Status:"
	@docker-compose ps

shell: ## Open a shell in the admin tools container
	@echo "Opening shell in admin-tools container..."
	@echo "You can now run temporal CLI commands."
	docker-compose exec temporal-admin-tools bash

shell-temporal: ## Open a shell in the Temporal server container
	docker-compose exec temporal bash

test-db: ## Test database connection
	@echo "Testing PostgreSQL connection..."
	docker-compose exec postgresql psql -U temporal -d temporal -c "SELECT version();"

create-namespace: ## Create default namespace
	@echo "Creating default namespace..."
	docker-compose exec temporal-admin-tools temporal operator namespace create default --retention 7
	@echo "Namespace 'default' created with 7-day retention"

list-namespaces: ## List all namespaces
	@echo "Listing namespaces..."
	docker-compose exec temporal-admin-tools temporal operator namespace list

health: ## Check Temporal cluster health
	@echo "Checking cluster health..."
	docker-compose exec temporal-admin-tools temporal operator cluster health

system-info: ## Show Temporal system information
	@echo "Getting system information..."
	docker-compose exec temporal-admin-tools temporal operator cluster system

clean: ## Stop services and remove volumes (WARNING: deletes all data)
	@echo "WARNING: This will delete all Temporal data!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose down -v; \
		echo "All services stopped and data removed."; \
	fi

restart: ## Restart all services
	@$(MAKE) down
	@$(MAKE) up

rebuild: ## Rebuild and restart all services
	@$(MAKE) down
	@$(MAKE) build
	@$(MAKE) up

# Development helpers
watch-logs: ## Watch logs with timestamps
	docker-compose logs -f --tail=100 --timestamps

ps: ## Show running containers
	docker-compose ps

top: ## Show running processes in containers
	docker-compose top

# Quick start target
start: build up create-namespace ## Build, start services, and create default namespace
	@echo ""
	@echo "✅ Temporal is ready!"
	@echo ""
	@echo "Next steps:"
	@echo "  - Web UI: http://localhost:8080"
	@echo "  - Connect your app to: localhost:7233"
	@echo "  - Run workflows in the 'default' namespace"
	@echo ""
	@echo "Useful commands:"
	@echo "  make logs        - View logs"
	@echo "  make shell       - Open CLI shell"
	@echo "  make status      - Check service status"

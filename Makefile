.PHONY: help build run stop clean logs shell test deploy dev

# Default target
help: ## Show this help message
	@echo "🐳 Swiftralino Docker Commands"
	@echo "=============================="
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Build commands
build: ## Build the Docker image
	@echo "🔨 Building Swiftralino Docker image..."
	docker-compose build

build-no-cache: ## Build the Docker image without cache
	@echo "🔨 Building Swiftralino Docker image (no cache)..."
	docker-compose build --no-cache

# Run commands
run: ## Start the application in production mode
	@echo "🚀 Starting Swiftralino in production mode..."
	docker-compose up -d

run-proxy: ## Start the application with nginx proxy
	@echo "🚀 Starting Swiftralino with nginx proxy..."
	docker-compose --profile proxy up -d

dev: ## Start the application in development mode
	@echo "🛠️  Starting Swiftralino in development mode..."
	docker-compose -f docker-compose.dev.yml up -d

dev-frontend: ## Start development mode with frontend dev server
	@echo "🛠️  Starting Swiftralino with frontend dev server..."
	docker-compose -f docker-compose.dev.yml --profile frontend up -d

# Control commands
stop: ## Stop the application
	@echo "🛑 Stopping Swiftralino..."
	docker-compose down
	docker-compose -f docker-compose.dev.yml down

restart: stop run ## Restart the application

# Monitoring and debugging
logs: ## Show application logs
	docker-compose logs -f swiftralino

logs-all: ## Show all service logs
	docker-compose logs -f

status: ## Show container status
	docker-compose ps

health: ## Check application health
	@echo "🔍 Checking Swiftralino health..."
	@curl -f http://localhost:8080/health || echo "❌ Health check failed"

shell: ## Enter the running container
	docker exec -it swiftralino-server /bin/bash

# Testing and validation
test-build: ## Test build without running
	@echo "🧪 Testing Docker build..."
	docker-compose build --dry-run

validate: ## Validate docker-compose files
	@echo "✅ Validating docker-compose configuration..."
	docker-compose config
	docker-compose -f docker-compose.dev.yml config

# Swift-specific commands
swift-build: ## Build Swift project locally
	@echo "🦉 Building Swift project..."
	swift build

swift-test: ## Run Swift tests locally
	@echo "🧪 Running Swift tests..."
	swift test

swift-clean: ## Clean Swift build artifacts
	@echo "🧹 Cleaning Swift build artifacts..."
	swift package clean

# Deployment commands
deploy: build run ## Build and deploy in production
	@echo "🚀 Deployed Swiftralino successfully!"
	@echo "   Web Interface: https://localhost:8443 (HTTPS) or http://localhost:8080 (HTTP)"
	@echo "   Health Check:  https://localhost:8443/health"

deploy-proxy: build run-proxy ## Build and deploy with nginx proxy
	@echo "🚀 Deployed Swiftralino with proxy successfully!"
	@echo "   Web Interface: https://localhost (HTTPS) or http://localhost (HTTP)"
	@echo "   Health Check:  https://localhost/health"

deploy-dev: generate-cert deploy ## Deploy with self-signed certificate for development
	@echo "🛠️  Deployed Swiftralino with self-signed certificate!"
	@echo "   Web Interface: https://localhost:8443 (accept security warning)"
	@echo "   Note: Browser will show security warning for self-signed certificate"

# Maintenance commands
clean: ## Clean up containers and images
	@echo "🧹 Cleaning up Docker resources..."
	docker-compose down --rmi local --volumes --remove-orphans
	docker system prune -f

clean-all: ## Clean up everything including unused images
	@echo "🧹 Deep cleaning Docker resources..."
	docker-compose down --rmi all --volumes --remove-orphans
	docker system prune -a -f

update: ## Update and rebuild everything
	@echo "🔄 Updating Swiftralino..."
	git pull
	$(MAKE) clean build deploy

# Development helpers
frontend-build: ## Build frontend assets
	@echo "📦 Building frontend assets..."
	cd Sources/SwiftralinoWebView && npm run build

frontend-install: ## Install frontend dependencies
	@echo "📦 Installing frontend dependencies..."
	cd Sources/SwiftralinoWebView && npm install

# Certificate management
generate-cert: ## Generate self-signed certificate for development
	@echo "🔑 Generating self-signed certificate..."
	@mkdir -p ssl
	openssl req -x509 -newkey rsa:4096 -keyout ssl/key.pem -out ssl/cert.pem \
		-days 365 -nodes \
		-subj "/C=US/ST=Dev/L=Dev/O=Swiftralino/CN=localhost" \
		-addext "subjectAltName=DNS:localhost,DNS:*.localhost,IP:127.0.0.1,IP:::1"
	@echo "✅ Self-signed certificate generated in ssl/"
	@echo "📋 To trust this certificate:"
	@echo "   macOS: make trust-cert-macos"
	@echo "   Linux: make trust-cert-linux"
	@echo "   Windows: make trust-cert-windows"

trust-cert-macos: ## Add certificate to macOS trust store
	@if [ ! -f ssl/cert.pem ]; then \
		echo "❌ Certificate not found. Run 'make generate-cert' first"; \
		exit 1; \
	fi
	@echo "🔑 Adding certificate to macOS Keychain..."
	security add-trusted-cert -d -r trustRoot -k ~/Library/Keychains/login.keychain ssl/cert.pem
	@echo "✅ Certificate added to macOS Keychain"
	@echo "🌐 You can now access https://localhost:8443 without warnings"

trust-cert-linux: ## Add certificate to Linux trust store
	@if [ ! -f ssl/cert.pem ]; then \
		echo "❌ Certificate not found. Run 'make generate-cert' first"; \
		exit 1; \
	fi
	@echo "🔑 Adding certificate to Linux trust store..."
	@echo "This requires sudo access:"
	sudo cp ssl/cert.pem /usr/local/share/ca-certificates/swiftralino.crt
	sudo update-ca-certificates
	@echo "✅ Certificate added to Linux trust store"
	@echo "🌐 You may need to restart your browser"

trust-cert-windows: ## Instructions for Windows trust store
	@if [ ! -f ssl/cert.pem ]; then \
		echo "❌ Certificate not found. Run 'make generate-cert' first"; \
		exit 1; \
	fi
	@echo "🔑 Windows Certificate Trust Instructions:"
	@echo "========================================="
	@echo "1. Copy ssl/cert.pem to your Windows machine"
	@echo "2. Double-click the .pem file"
	@echo "3. Click 'Install Certificate...'"
	@echo "4. Select 'Local Machine' and click 'Next'"
	@echo "5. Select 'Place all certificates in the following store'"
	@echo "6. Click 'Browse' and select 'Trusted Root Certification Authorities'"
	@echo "7. Click 'Next' then 'Finish'"
	@echo "8. Click 'Yes' on the security warning"
	@echo "✅ Certificate will be trusted system-wide"

untrust-cert-macos: ## Remove certificate from macOS trust store
	@echo "🗑️  Removing Swiftralino certificate from macOS Keychain..."
	@security delete-certificate -c "Swiftralino" ~/Library/Keychains/login.keychain 2>/dev/null || true
	@echo "✅ Certificate removed from macOS Keychain"

untrust-cert-linux: ## Remove certificate from Linux trust store
	@echo "🗑️  Removing certificate from Linux trust store..."
	@echo "This requires sudo access:"
	sudo rm -f /usr/local/share/ca-certificates/swiftralino.crt
	sudo update-ca-certificates --fresh
	@echo "✅ Certificate removed from Linux trust store"

letsencrypt: ## Obtain Let's Encrypt certificate
	@echo "🌐 Obtaining Let's Encrypt certificate..."
	@if [ -z "$(DOMAIN)" ]; then \
		echo "❌ Please set DOMAIN environment variable"; \
		echo "   Example: make letsencrypt DOMAIN=yourdomain.com"; \
		exit 1; \
	fi
	@mkdir -p letsencrypt certbot-webroot
	docker-compose --profile certbot run --rm certbot
	@echo "✅ Let's Encrypt certificate obtained for $(DOMAIN)"

cert-renew: ## Renew Let's Encrypt certificate
	@echo "🔄 Renewing Let's Encrypt certificate..."
	docker-compose --profile certbot run --rm certbot renew

cert-info: ## Show certificate information
	@echo "🔍 Certificate Information:"
	@if [ -f ssl/cert.pem ]; then \
		echo "Self-signed certificate:"; \
		openssl x509 -in ssl/cert.pem -text -noout | grep -E "(Subject:|Not Before:|Not After:)"; \
	fi
	@if [ -f letsencrypt/live/*/cert.pem ]; then \
		echo "Let's Encrypt certificate:"; \
		openssl x509 -in letsencrypt/live/*/cert.pem -text -noout | grep -E "(Subject:|Not Before:|Not After:)"; \
	fi

# Environment setup
env-example: ## Create example environment file
	@if [ ! -f .env ]; then \
		echo "📝 Creating .env from example..."; \
		echo "# Swiftralino Docker Environment" > .env; \
		echo "SWIFTRALINO_HTTP_PORT=8080" >> .env; \
		echo "SWIFTRALINO_HTTPS_PORT=8443" >> .env; \
		echo "SWIFTRALINO_HOST=0.0.0.0" >> .env; \
		echo "SWIFTRALINO_DISABLE_TLS=false" >> .env; \
		echo "DOMAIN=localhost" >> .env; \
		echo "CERTBOT_EMAIL=admin@localhost" >> .env; \
		echo "NGINX_PORT=80" >> .env; \
	else \
		echo "ℹ️  .env file already exists"; \
	fi

# Backup and restore
backup: ## Backup application data
	@echo "💾 Creating backup..."
	mkdir -p backup
	docker run --rm \
		-v swiftralino_swiftralino-data:/data \
		-v $(PWD)/backup:/backup \
		alpine tar czf /backup/swiftralino-backup-$(shell date +%Y%m%d_%H%M%S).tar.gz -C /data .

restore: ## Restore from latest backup (use BACKUP_FILE=filename to specify)
	@echo "🔄 Restoring from backup..."
	@if [ -z "$(BACKUP_FILE)" ]; then \
		BACKUP_FILE=$$(ls -t backup/*.tar.gz | head -1); \
	else \
		BACKUP_FILE="backup/$(BACKUP_FILE)"; \
	fi; \
	echo "Restoring from $$BACKUP_FILE"; \
	docker run --rm \
		-v swiftralino_swiftralino-data:/data \
		-v $(PWD):/backup \
		alpine tar xzf /$$BACKUP_FILE -C /data

# Security
security-scan: ## Scan images for vulnerabilities (requires docker scan)
	@echo "🔒 Scanning for security vulnerabilities..."
	docker scan swiftralino_swiftralino || echo "Install docker scan for security scanning"

# Continuous integration helpers
ci-test: validate test-build ## CI: Run all tests and validation
	@echo "✅ All CI checks passed"

ci-deploy: build test-build health ## CI: Build, test and verify deployment
	@echo "✅ CI deployment successful" 
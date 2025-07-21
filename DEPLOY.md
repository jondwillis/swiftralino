# 🐳 Swiftralino Docker Deployment Guide

This guide explains how to deploy Swiftralino as a headless server using Docker
and Docker Compose.

## 🔒 Security First

**Swiftralino defaults to HTTPS/TLS for security.** You'll need certificates to
run in production mode. Only disable TLS for development when explicitly needed.

## 🏗️ Architecture

The Docker deployment consists of:

- **Swift Backend**: Headless Swiftralino server (no WebView/GUI)
- **WebSocket Bridge**: Real-time communication with frontends
- **Static Assets**: Pre-built React frontend served by the Swift server
- **Optional Nginx**: Reverse proxy with SSL, caching, and rate limiting

## 📋 Quick Start

### 1. Prerequisites

- Docker Engine 20.10+
- Docker Compose v2.0+
- At least 1GB RAM available

### 2. Certificate Setup (Required)

Choose your certificate option:

```bash
# Option A: Self-signed certificate (Development)
make generate-cert

# Option B: Let's Encrypt certificate (Production)
DOMAIN=yourdomain.com CERTBOT_EMAIL=you@domain.com make letsencrypt

# Option C: Disable TLS (Not recommended)
echo "SWIFTRALINO_DISABLE_TLS=true" >> .env
```

### 3. Environment Setup

Copy the example environment file and customize:

```bash
# Create environment file
make env-example

# Edit configuration (optional)
nano .env
```

### 4. Build and Deploy

```bash
# Development deployment with self-signed cert
make deploy-dev

# Production deployment (requires valid certificates)
make deploy

# With nginx proxy and Let's Encrypt
make deploy-proxy
```

### 5. Access Your Application

- **Web Interface**: https://localhost:8443 (HTTPS) or http://localhost:8080
  (HTTP)
- **WebSocket Bridge**: wss://localhost:8443/bridge
- **Health Check**: https://localhost:8443/health
- **With Proxy**: https://localhost (port 443)

## 🔧 Configuration Options

### Environment Variables

```bash
# Server Configuration
SWIFTRALINO_HOST=0.0.0.0          # Bind address
SWIFTRALINO_HTTP_PORT=8080        # HTTP port
SWIFTRALINO_HTTPS_PORT=8443       # HTTPS port
SWIFTRALINO_DISABLE_TLS=false     # Disable TLS (not recommended)
SWIFTRALINO_ENV=production        # Environment mode

# Certificate Configuration
DOMAIN=localhost                  # Domain for Let's Encrypt
CERTBOT_EMAIL=admin@localhost     # Email for Let's Encrypt

# Nginx Proxy
NGINX_PORT=80                     # HTTP port
NGINX_SSL_PORT=443                # HTTPS port

# Performance
MEMORY_LIMIT=512M                 # Container memory limit
CPU_LIMIT=1.0                     # Container CPU limit
SWIFT_LOG_LEVEL=info             # Logging level
```

### Resource Limits

The Docker containers are configured with sensible defaults:

- **Memory**: 512MB limit, 128MB reserved
- **CPU**: 1.0 core limit, 0.25 core reserved
- **Disk**: Minimal (stateless by design)

## 🚀 Deployment Scenarios

### Basic Headless Server

```bash
# Minimal deployment - just the Swift server
docker-compose up -d swiftralino
```

Serves:

- Web frontend at http://localhost:8080
- WebSocket API at ws://localhost:8080/bridge
- REST API at http://localhost:8080/api
- System APIs accessible via WebSocket

### Production with Reverse Proxy

```bash
# Full production setup with Nginx
docker-compose --profile proxy up -d
```

Features:

- SSL termination (configure certificates)
- Static asset caching
- API rate limiting
- WebSocket proxy support
- Security headers

### Development Setup

```bash
# Development with live reload
docker-compose -f docker-compose.dev.yml up -d

# Include frontend dev server
docker-compose -f docker-compose.dev.yml --profile frontend up -d
```

Development features:

- Source code mounted for live reload
- Debug logging enabled
- Frontend dev server with hot reload
- Direct container access for debugging

## 🔒 Security Considerations

### Production Checklist

- [ ] Change default ports if exposed publicly
- [ ] Configure SSL certificates for HTTPS
- [ ] Review nginx security headers
- [ ] Enable API rate limiting
- [ ] Use non-root container user (already configured)
- [ ] Regular security updates for base images

### SSL/HTTPS Setup

**TLS is enabled by default.** Choose your certificate method:

1. **Let's Encrypt (Production)**:
   ```bash
   # Set your domain and email
   export DOMAIN=yourdomain.com
   export CERTBOT_EMAIL=you@domain.com

   # Obtain certificate
   make letsencrypt

   # Deploy with proxy
   make deploy-proxy
   ```

2. **Self-signed certificate (Development)**:
   ```bash
   # Generate certificate
   make generate-cert

   # Add to system trust store (eliminates browser warnings)
   make trust-cert-macos    # macOS
   make trust-cert-linux    # Linux

   # Deploy
   make deploy-dev
   ```

3. **Custom certificates**:
   ```bash
   # Place your certificates in ssl/ directory
   mkdir ssl
   cp your-cert.pem ssl/cert.pem
   cp your-key.pem ssl/key.pem

   # Deploy
   make deploy
   ```

4. **Disable TLS (Not recommended)**:
   ```bash
   echo "SWIFTRALINO_DISABLE_TLS=true" >> .env
   make deploy
   ```

### Certificate Trust Store Setup

To eliminate browser security warnings for self-signed certificates, add your
certificate to your system's trust store:

#### 🍎 macOS

```bash
# Generate and trust certificate automatically
make generate-cert
make trust-cert-macos

# Or manually via Keychain Access:
# 1. Open Keychain Access
# 2. File → Import Items → Select ssl/cert.pem
# 3. Double-click imported certificate
# 4. Expand "Trust" section
# 5. Set "Secure Sockets Layer (SSL)" to "Always Trust"
```

#### 🐧 Linux

```bash
# Generate and trust certificate automatically
make generate-cert
make trust-cert-linux

# Or manually:
sudo cp ssl/cert.pem /usr/local/share/ca-certificates/swiftralino.crt
sudo update-ca-certificates
```

#### 🪟 Windows

```bash
# Generate certificate first
make generate-cert

# Follow manual instructions
make trust-cert-windows

# Or use PowerShell as Administrator:
# Import-Certificate -FilePath "ssl\cert.pem" -CertStoreLocation "Cert:\LocalMachine\Root"
```

#### 🌐 Browser-Specific (Alternative)

Some browsers (like Chrome) maintain separate certificate stores:

**Chrome/Edge:**

1. Go to `chrome://settings/certificates`
2. Click "Authorities" tab
3. Click "Import" and select `ssl/cert.pem`
4. Check "Trust this certificate for identifying websites"

**Firefox:**

1. Go to `about:preferences#privacy`
2. Scroll to "Certificates" → "View Certificates"
3. Click "Authorities" tab → "Import"
4. Select `ssl/cert.pem`
5. Check "Trust this CA to identify websites"

#### Certificate Cleanup

When done developing, remove the certificate:

```bash
make untrust-cert-macos    # macOS
make untrust-cert-linux    # Linux
```

## 🔍 Monitoring and Debugging

### Health Checks

```bash
# Check container health
docker-compose ps

# View logs
docker-compose logs -f swiftralino

# Health check endpoint
curl http://localhost:8080/health
```

### Performance Monitoring

```bash
# Container resource usage
docker stats

# Detailed container info
docker inspect swiftralino-server
```

### Debugging

```bash
# Enter running container
docker exec -it swiftralino-server /bin/bash

# View Swift server logs
docker logs swiftralino-server -f

# Check network connectivity
docker network ls
docker network inspect swiftralino_swiftralino-network
```

## 📊 Scaling and Performance

### Horizontal Scaling

```bash
# Scale to multiple instances
docker-compose up -d --scale swiftralino=3

# Load balancing with nginx
# (nginx.conf automatically balances across instances)
```

### Performance Tuning

1. **Memory optimization**:
   ```yaml
   # In docker-compose.yml
   environment:
     - SWIFT_HEAP_SIZE=256M
   ```

2. **CPU optimization**:
   ```yaml
   deploy:
     resources:
       limits:
         cpus: '2.0'  # Increase for high-traffic
   ```

3. **Disk I/O**:
   ```bash
   # Use volume for better I/O
   volumes:
     - swiftralino-cache:/app/cache
   ```

## 🔄 Updates and Maintenance

### Updating the Application

```bash
# Pull latest changes
git pull

# Rebuild and restart
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### Database Migrations (if applicable)

```bash
# Run migrations
docker exec swiftralino-server /app/migrate

# Or with compose
docker-compose run swiftralino /app/migrate
```

### Backup and Restore

```bash
# Backup volumes
docker run --rm \
  -v swiftralino_swiftralino-data:/data \
  -v $(pwd)/backup:/backup \
  alpine tar czf /backup/swiftralino-backup.tar.gz -C /data .

# Restore volumes
docker run --rm \
  -v swiftralino_swiftralino-data:/data \
  -v $(pwd)/backup:/backup \
  alpine tar xzf /backup/swiftralino-backup.tar.gz -C /data
```

## 🐛 Troubleshooting

### Common Issues

1. **Port conflicts**:
   ```bash
   # Change port in .env file
   echo "SWIFTRALINO_PORT=8081" >> .env
   ```

2. **Memory issues**:
   ```bash
   # Increase memory limit
   echo "MEMORY_LIMIT=1G" >> .env
   ```

3. **WebSocket connection issues**:
   ```bash
   # Check firewall settings
   # Verify nginx WebSocket proxy configuration
   ```

4. **Build failures**:
   ```bash
   # Clean build
   docker-compose build --no-cache

   # Check disk space
   docker system df
   docker system prune
   ```

### Getting Help

- Check the logs: `docker-compose logs swiftralino`
- Verify health: `curl http://localhost:8080/health`
- Test WebSocket: Use browser dev tools to connect to
  `ws://localhost:8080/bridge`

## 🌐 Cloud Deployment

### AWS/Azure/GCP

```bash
# Example for cloud deployment
export SWIFTRALINO_HOST=0.0.0.0
export SWIFTRALINO_PORT=8080
export DOMAIN=your-domain.com

docker-compose --profile proxy up -d
```

### Kubernetes

See `k8s/` directory for Kubernetes manifests (if created).

### Docker Swarm

```bash
# Deploy to swarm
docker stack deploy -c docker-compose.yml swiftralino
```

---

## 📝 Next Steps

1. **Customize the frontend**: Modify files in `Sources/SwiftralinoWebView/`
2. **Add custom APIs**: Extend the Swift backend in `Sources/SwiftralinoCore/`
3. **Configure monitoring**: Add Prometheus/Grafana for metrics
4. **Set up CI/CD**: Automate deployments with GitHub Actions

Happy deploying! 🚀

# Swiftralino

**Swiftralino** is a secure-by-default, Swift-native framework for building
cross-platform desktop applications. Inspired by Tauri and Neutralino, it uses
Swift for the backend and web technologies for the frontend, with **HTTPS/TLS
enabled by default** for security.

## ✨ Features

- **🔒 Secure by Default**: TLS/HTTPS enabled everywhere, including development
- **⚡ Swift-Native**: Pure Swift backend with async/await support
- **🌐 Web Frontend**: React/TypeScript frontend with full access to Swift APIs
- **📡 WebSocket Bridge**: Real-time communication between Swift and JavaScript
- **🐳 Docker Ready**: Headless deployment for cloud/server environments
- **🧪 Modern Testing**: Swift Testing framework with comprehensive test
  coverage
- **🔧 Developer Friendly**: Hot reload, development tools, and easy certificate
  setup

## 🚀 Quick Start

### 1. Prerequisites

- **macOS 12.0+** with Xcode 15.0+
- **Swift 5.9+**
- **Node.js 18+** (for frontend development)

### 2. First-Time Setup

```bash
# Clone the repository
git clone <repository-url>
cd swiftralino

# Generate development certificates (required for HTTPS)
make generate-cert

# Trust the certificate (eliminates browser warnings)
make trust-cert-macos

# Build frontend assets
make frontend-install frontend-build

# Run the demo application
make demo
```

### 3. Access Your Application

- **🌐 Web Interface**: https://localhost:8080
- **🔗 WebSocket API**: wss://localhost:8080/bridge
- **✅ Secure Connection**: No browser warnings with trusted certificates

## 🔒 Security & Certificates

### Why TLS by Default?

Swiftralino enables **HTTPS/TLS by default** in all environments because:

- **🛡️ Security First**: No insecure development habits
- **🔄 Dev-Prod Parity**: Same security model everywhere
- **🌍 Modern Web**: HTTPS is required for many web APIs
- **🔐 Best Practices**: Industry standard for networked applications

### Development Certificate Setup

**Option 1: Self-Signed Certificate (Recommended for Development)**

```bash
# Generate and trust certificate
make generate-cert
make trust-cert-macos  # or trust-cert-linux
```

**Option 2: Disable TLS (Not Recommended)**

```swift
let serverConfig = ServerConfiguration(
    host: "127.0.0.1",
    port: 8080,
    enableTLS: false  // Shows security warning
)
```

## 🛠️ Development

### Running Tests

```bash
# Run all tests with Swift Testing
swift test --parallel

# Run specific test suites
swift test --filter "SwiftralinoTests"
swift test --filter "DistributedPlatformTests"

# Run performance tests
swift test --filter "performance"

# Skip slow tests
swift test --skip-tags slow
```

### Frontend Development

```bash
# Install dependencies and start dev server
cd Sources/SwiftralinoWebView
npm install
npm run dev

# Build for production
npm run build
```

### Docker Deployment

```bash
# Quick deployment with self-signed certificates
make generate-cert
make deploy-dev

# Production deployment with Let's Encrypt
DOMAIN=yourdomain.com CERTBOT_EMAIL=you@domain.com make deploy-proxy
```

## 🏗️ Architecture

```
┌─────────────────┐    HTTPS/WSS     ┌─────────────────┐
│   Web Frontend  │◄────────────────►│  Swift Backend  │
│  (React/TypeScript) │              │   (Vapor/NIO)   │
└─────────────────┘                  └─────────────────┘
                                            │
                                     ┌──────▼──────┐
                                     │   Swift APIs │
                                     │ • FileSystem │
                                     │ • System Info│
                                     │ • Distributed│
                                     └─────────────┘
```

## 🔧 Configuration

### Server Configuration

```swift
let serverConfig = ServerConfiguration(
    host: "127.0.0.1",           // Bind address
    port: 8080,                  // Server port
    enableTLS: true              // TLS enabled by default
)
```

### WebView Configuration

```swift
let webViewConfig = WebViewConfiguration(
    initialURL: "https://127.0.0.1:8080",  // HTTPS by default
    windowTitle: "My App",
    windowWidth: 1200,
    windowHeight: 800,
    enableDeveloperTools: true
)
```

## 📚 API Examples

### Swift to JavaScript

```swift
// In your Swift API
func execute(parameters: [String: AnyCodable]?) async throws -> [String: Any] {
    return [
        "message": "Hello from Swift!",
        "timestamp": Date().timeIntervalSince1970,
        "systemInfo": await getSystemInfo()
    ]
}
```

### JavaScript to Swift

```typescript
// In your React/TypeScript frontend
import { swiftralino } from "./lib/swiftralino-client";

const result = await swiftralino.api.system.info();
console.log("Swift response:", result);

const files = await swiftralino.api.filesystem.readDirectory("/Users");
console.log("Directory contents:", files);
```

## 🚢 Deployment Options

### Development

- **Local**: `make demo` (with self-signed certificates)
- **Docker**: `make deploy-dev` (containerized development)

### Production

- **Self-Hosted**: `make deploy` (Docker with custom certificates)
- **Cloud**: `make deploy-proxy` (Docker + Nginx + Let's Encrypt)
- **Headless**: Docker-only deployment without WebView GUI

## 🤝 Contributing

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Add** tests for your changes
4. **Run** tests: `swift test --parallel`
5. **Commit** changes (`git commit -m 'Add amazing feature'`)
6. **Push** to branch (`git push origin feature/amazing-feature`)
7. **Create** a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file
for details.

## 🙏 Acknowledgments

- **[Tauri](https://tauri.app/)** - Inspiration for the architecture
- **[Neutralino](https://neutralino.js.org/)** - Lightweight app framework
  concepts
- **[Vapor](https://vapor.codes/)** - Swift web framework
- **[Swift Testing](https://github.com/apple/swift-testing)** - Modern testing
  framework

---

**Swiftralino**: Build secure, Swift-native desktop applications with web
frontends. 🚀🔒

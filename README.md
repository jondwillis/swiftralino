# ⚡ Swiftralino

A lightweight cross-platform desktop application framework that implements
Neutralino's paradigm using Swift backend with web frontend, delivering native
performance without Electron's bloat.

## 🎯 Project Goals

Swiftralino implements the vision outlined in our research to create a
Swift-based alternative to Electron and similar frameworks by:

- **Leveraging Swift's Performance**: Utilizing Swift's compiled nature, ARC
  memory management, and modern concurrency features
- **Cross-Platform Support**: Targeting macOS, Linux, and Windows with
  platform-specific WebView implementations
- **Lightweight Communication**: Implementing efficient WebSocket-based IPC
  between Swift backend and web frontend
- **Security-First Architecture**: Following Tauri's security model with
  actor-based state management
- **Native Integration**: Providing seamless access to system APIs through
  type-safe Swift interfaces

## 🏗️ Architecture

Swiftralino follows a hybrid architecture combining Tauri's security model with
Neutralino's lightweight communication patterns:

```
┌─────────────────┐     WebSocket      ┌─────────────────┐
│   Web Frontend  │ ◄──────────────► │  Swift Backend  │
│   (HTML/CSS/JS) │     Bridge        │   (Actor-based) │
└─────────────────┘                   └─────────────────┘
         │                                      │
         ▼                                      ▼
┌─────────────────┐                   ┌─────────────────┐
│   Platform      │                   │    System       │
│   WebView       │                   │    APIs         │
│ (WKWebView/etc) │                   │ (File/Process)  │
└─────────────────┘                   └─────────────────┘
```

### Core Components

1. **SwiftralinoApp**: Main application actor coordinating all components
2. **WebServer**: Vapor-based WebSocket server handling frontend-backend
   communication
3. **WebViewManager**: Platform-specific WebView abstraction layer
4. **MessageHandler**: Processes API calls with type-safe contracts
5. **APIRegistry**: Extensible system for registering native Swift APIs

## 🚀 Quick Start

### Prerequisites

- Swift 5.9 or later
- macOS 12+ (for macOS WebView support)
- Linux (experimental WebView support)

### Building and Running

0. Swift Version a. Download swiftly

```bash
curl -O https://download.swift.org/swiftly/darwin/swiftly.pkg && \
installer -pkg swiftly.pkg -target CurrentUserHomeDirectory && \
~/.swiftly/bin/swiftly init --quiet-shell-followup && \
. "${SWIFTLY_HOME_DIR:-$HOME/.swiftly}/env.sh" && \
hash -r
```

Otherwise, download Swift 6.1.2+

1. **Clone and navigate to the project:**
   ```bash
   cd swiftralino
   ```

2. **Build the project:**
   ```bash
   swift build
   ```

3. **Run the demo application:**
   ```bash
   swift run
   ```

4. **Test the application:**
   - The app will launch with both a WebSocket server and WebView window
   - Open http://127.0.0.1:8080 in your browser (if WebView doesn't appear)
   - Try the interactive demo features:
     - System information queries
     - File system operations
     - Process execution
     - WebSocket bridge communication

## 📱 Platform Support

| Platform | WebView   | Status     | Implementation             |
| -------- | --------- | ---------- | -------------------------- |
| macOS    | WKWebView | ✅ Working | Native Cocoa integration   |
| Linux    | WebKitGTK | 🚧 Planned | SwiftGtk bindings          |
| Windows  | WebView2  | 🚧 Planned | C++ interop or alternative |

## 🛠️ Development

### Project Structure

```
swiftralino/
├── Sources/
│   ├── Swiftralino/           # Main executable
│   │   └── main.swift
│   └── SwiftralinoCore/       # Core framework
│       ├── SwiftralinoApp.swift     # Main application actor
│       ├── WebServer.swift          # WebSocket server
│       ├── WebViewManager.swift     # Platform WebView abstraction
│       └── MessageHandler.swift     # API message processing
├── Public/                    # Static web assets
│   └── index.html            # Demo frontend
├── Tests/                    # Test suite
├── Package.swift             # Swift Package Manager configuration
└── README.md
```

### Adding Custom APIs

Extend the framework by implementing the `SwiftralinoAPI` protocol:

```swift
public struct CustomAPI: SwiftralinoAPI {
    public let name = "custom"
    public let description = "Custom API functionality"
    
    public func execute(parameters: [String: AnyCodable]?) async throws -> [String: Any] {
        // Your custom API implementation
        return ["result": "success"]
    }
}

// Register in MessageHandler
await apiRegistry.register(CustomAPI())
```

### Frontend Integration

The JavaScript bridge provides easy access to Swift APIs:

```javascript
// System information
const info = await window.Swiftralino.system.info();

// File operations
const files = await window.Swiftralino.filesystem.readDirectory("/path");

// Process execution
const result = await window.Swiftralino.process.execute("ls", ["-la"]);

// Custom API calls
const response = await window.Swiftralino.callAPI("custom", { param: "value" });
```

## 🎯 Performance Characteristics

Based on our research and initial implementation:

- **Startup Time**: ~50ms (vs Electron's ~800ms)
- **Memory Usage**: 15-30MB baseline (vs Electron's 200-400MB)
- **Binary Size**: Targeting ~2.5MB (similar to Tauri)
- **Communication Overhead**: Minimal WebSocket-based IPC

## 🔒 Security Features

- **Actor-Based Isolation**: Swift actors ensure thread-safe state management
- **Message Validation**: Type-safe API contracts prevent injection attacks
- **Sandboxed Execution**: Platform-specific sandboxing for system operations
- **Minimal Attack Surface**: Only explicitly registered APIs are exposed

## 🧪 Testing

Run the test suite:

```bash
swift test
```

For manual testing, the demo application provides interactive examples of all
major features.

## 🗺️ Roadmap

### Phase 1: Core Architecture ✅

- [x] WebSocket server implementation
- [x] macOS WebView integration
- [x] Basic API system (filesystem, system, process)
- [x] Actor-based state management

### Phase 2: Platform Expansion 🚧

- [ ] Linux WebView support (WebKitGTK)
- [ ] Windows WebView support (WebView2)
- [ ] Cross-platform build system
- [ ] Enhanced security features

### Phase 3: Optimization & Polish 🔮

- [ ] Performance optimizations
- [ ] Advanced packaging
- [ ] Developer tooling
- [ ] Documentation and examples

## 🤝 Contributing

We welcome contributions! Key areas of interest:

1. **Linux WebView Implementation**: WebKitGTK integration through SwiftGtk
2. **Windows Support**: WebView2 bindings or alternative approaches
3. **API Extensions**: New system APIs and functionality
4. **Performance Optimizations**: Memory usage and startup time improvements
5. **Security Enhancements**: Additional sandboxing and validation

## 📚 Research Background

This project implements the vision described in our research document, which
identified Swift as an ideal candidate for lightweight desktop applications due
to:

- Superior performance characteristics compared to JavaScript runtimes
- Memory safety without garbage collection overhead
- Modern concurrency features with actors and async/await
- Growing cross-platform ecosystem

For detailed analysis, see [docs/research.md](docs/research.md).

## 📄 License

MIT License - see LICENSE file for details.

## 🙏 Acknowledgments

Inspired by:

- [Neutralino.js](https://neutralino.js.org/) - Lightweight cross-platform app
  development
- [Tauri](https://tauri.app/) - Rust-based application framework
- [Electron](https://electronjs.org/) - The framework we aim to make more
  efficient

Built with:

- [Vapor](https://vapor.codes/) - Swift server framework
- [Swift Package Manager](https://swift.org/package-manager/) - Dependency
  management
- Modern web technologies for frontend development

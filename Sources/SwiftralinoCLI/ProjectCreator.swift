import Foundation

public struct ProjectCreator {
    public init() {}
    
    public func create(name: String, template: CreateCommand.Template, skipDeps: Bool) throws {
        let projectPath = name
        
        // Validate project name
        try validateProjectName(name)
        
        // Create project directory
        try createProjectDirectory(at: projectPath)
        
        // Generate configuration
        let identifier = "com.swiftralino.\(name.lowercased().replacingOccurrences(of: " ", with: "-"))"
        let config = SwiftralinoConfig.defaultConfig(
            appName: name,
            identifier: identifier,
            template: template
        )
        
        // Create project structure
        try createProjectStructure(at: projectPath, template: template)
        
        // Generate configuration file
        try config.save(to: "\(projectPath)/swiftralino.json")
        
        // Create Swift Package.swift
        try createPackageManifest(at: projectPath, appName: name)
        
        // Create main.swift
        try createMainSwift(at: projectPath, appName: name)
        
        // Create frontend based on template
        try createFrontend(at: projectPath, template: template, appName: name)
        
        // Install dependencies if not skipped
        if !skipDeps {
            try installDependencies(at: projectPath, template: template)
        }
        
        print("📄 Generated swiftralino.json configuration")
        print("🎯 Project structure created for template: \(template.rawValue)")
        
        if skipDeps {
            print("⏭️  Dependencies skipped - run installation manually:")
            print("   📦 cd \(projectPath) && swift package resolve")
            if template != .vanilla {
                print("   🌐 cd \(projectPath)/frontend && npm install")
            }
        }
    }
    
    private func validateProjectName(_ name: String) throws {
        guard !name.isEmpty else {
            throw ProjectError.invalidName("Project name cannot be empty")
        }
        
        guard !FileManager.default.fileExists(atPath: name) else {
            throw ProjectError.directoryExists("Directory '\(name)' already exists")
        }
        
        // Check for valid characters
        let validCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard name.rangeOfCharacter(from: validCharacters.inverted) == nil else {
            throw ProjectError.invalidName("Project name can only contain alphanumeric characters, hyphens, and underscores")
        }
    }
    
    private func createProjectDirectory(at path: String) throws {
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    }
    
    private func createProjectStructure(at path: String, template: CreateCommand.Template) throws {
        // Create Swift source directories
        try FileManager.default.createDirectory(atPath: "\(path)/Sources", withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: "\(path)/Sources/\(path.capitalized)", withIntermediateDirectories: true)
        
        // Create frontend directory based on template
        switch template {
        case .vanilla:
            try FileManager.default.createDirectory(atPath: "\(path)/public", withIntermediateDirectories: true)
        default:
            try FileManager.default.createDirectory(atPath: "\(path)/frontend", withIntermediateDirectories: true)
        }
        
        // Create additional directories
        try FileManager.default.createDirectory(atPath: "\(path)/Resources", withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: "\(path)/.swiftralino", withIntermediateDirectories: true)
        
        print("📁 Created project directory structure")
    }
    
    private func createPackageManifest(at path: String, appName: String) throws {
        let packageContent = generatePackageSwift(appName: appName)
        try packageContent.write(toFile: "\(path)/Package.swift", atomically: true, encoding: .utf8)
        print("📦 Created Package.swift manifest")
    }
    
    private func createMainSwift(at path: String, appName: String) throws {
        let mainContent = generateMainSwift(appName: appName)
        try mainContent.write(toFile: "\(path)/Sources/\(appName.capitalized)/main.swift", atomically: true, encoding: .utf8)
        print("🚀 Created main.swift entry point")
    }
    
    private func createFrontend(at path: String, template: CreateCommand.Template, appName: String) throws {
        switch template {
        case .vanilla:
            try createVanillaFrontend(at: path, appName: appName)
        case .react:
            try createReactFrontend(at: path, appName: appName)
        case .vue:
            try createVueFrontend(at: path, appName: appName)
        case .svelte:
            try createSvelteFrontend(at: path, appName: appName)
        case .desktop, .mobile:
            try createReactFrontend(at: path, appName: appName) // Use React as base for now
        }
    }
    
    private func installDependencies(at path: String, template: CreateCommand.Template) throws {
        print("📦 Installing Swift dependencies...")
        let swiftResult = runCommand("swift package resolve", in: path)
        if swiftResult != 0 {
            print("⚠️  Warning: Swift package resolution failed")
        }
        
        if template != .vanilla {
            print("🌐 Installing frontend dependencies...")
            let frontendPath = "\(path)/frontend"
            
            // Try different package managers
            let managers = [
                ("bun", "bun install"),
                ("npm", "npm install"),
                ("yarn", "yarn install")
            ]
            
            var installed = false
            for (manager, command) in managers {
                if isToolAvailable(manager) {
                    let result = runCommand(command, in: frontendPath)
                    if result == 0 {
                        installed = true
                        print("✅ Installed frontend dependencies with \(manager)")
                        break
                    }
                }
            }
            
            if !installed {
                print("⚠️  Warning: Could not install frontend dependencies. Please install manually.")
            }
        }
    }
    
    // MARK: - Template Generators
    
    private func generatePackageSwift(appName: String) -> String {
        return """
        // swift-tools-version: 5.9
        import PackageDescription
        
        let package = Package(
            name: "\(appName)",
            platforms: [
                .macOS(.v12),
            ],
            products: [
                .executable(
                    name: "\(appName.lowercased())",
                    targets: ["\(appName.capitalized)"]
                ),
            ],
            dependencies: [
                .package(url: "https://github.com/your-org/swiftralino.git", branch: "main"),
            ],
            targets: [
                .executableTarget(
                    name: "\(appName.capitalized)",
                    dependencies: [
                        .product(name: "SwiftralinoCore", package: "swiftralino"),
                        .product(name: "SwiftralinoPlatform", package: "swiftralino"),
                    ]
                ),
            ]
        )
        """
    }
    
    private func generateMainSwift(appName: String) -> String {
        return """
        import Foundation
        import SwiftralinoCore
        import SwiftralinoPlatform
        
        #if canImport(Cocoa)
        import Cocoa
        #endif
        
        @main
        struct \(appName.capitalized)App {
            static func main() {
                print("🚀 Starting \(appName)")
                
                #if canImport(Cocoa)
                let app = NSApplication.shared
                app.setActivationPolicy(.regular)
                
                let delegate = SwiftralinoAppDelegate()
                app.delegate = delegate
                
                // Load configuration
                guard let config = try? SwiftralinoConfig.load() else {
                    print("❌ Failed to load swiftralino.json configuration")
                    print("   Make sure you're running from a Swiftralino project directory")
                    exit(1)
                }
                
                // Create application configuration
                let serverConfig = ServerConfiguration(
                    host: "127.0.0.1",
                    port: 8080
                )
                
                let webViewConfig = WebViewConfiguration(
                    initialURL: "http://127.0.0.1:8080",
                    windowTitle: config.app.productName,
                    windowWidth: config.app.windows.first?.width ?? 1024,
                    windowHeight: config.app.windows.first?.height ?? 768
                )
                
                let appConfig = AppConfiguration(
                    server: serverConfig,
                    webView: webViewConfig
                )
                
                // Create WebView manager and Swiftralino application
                let webViewManager = WebViewManager(configuration: webViewConfig)
                let swiftralinoApp = SwiftralinoApp(configuration: appConfig, webViewManager: webViewManager)
                delegate.swiftralinoApp = swiftralinoApp
                
                // Set up signal handling for graceful shutdown - improved version
                var signalSourceInt: DispatchSourceSignal?
                var signalSourceTerm: DispatchSourceSignal?
                var isShuttingDown = false
                
                let shutdownHandler = {
                    guard !isShuttingDown else { return }
                    isShuttingDown = true
                    
                    print("\\n🛑 Received shutdown signal")
                    
                    // Cancel signal sources first to prevent race conditions
                    signalSourceInt?.cancel()
                    signalSourceTerm?.cancel()
                    
                    Task {
                        await swiftralinoApp.shutdown()
                        
                        // Use a cleaner exit for development mode
                        #if DEBUG
                        print("🔄 Exiting development mode cleanly...")
                        DispatchQueue.main.async {
                            Foundation.exit(0)
                        }
                        #else
                        DispatchQueue.main.async {
                            NSApp.terminate(nil)
                        }
                        #endif
                    }
                }
                
                signalSourceInt = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
                signalSourceTerm = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
                
                signalSourceInt?.setEventHandler(handler: shutdownHandler)
                signalSourceTerm?.setEventHandler(handler: shutdownHandler)
                
                signal(SIGINT, SIG_IGN)
                signal(SIGTERM, SIG_IGN)
                signalSourceInt?.resume()
                signalSourceTerm?.resume()
                
                // Launch the application
                Task {
                    do {
                        try await swiftralinoApp.launch()
                        print("✅ \(appName) started successfully!")
                    } catch {
                        print("❌ Failed to start application: \\(error)")
                        
                        // Clean up signal sources on error
                        signalSourceInt?.cancel()
                        signalSourceTerm?.cancel()
                        
                        DispatchQueue.main.async {
                            #if DEBUG
                            Foundation.exit(1)
                            #else
                            NSApp.terminate(nil)
                            #endif
                        }
                    }
                }
                
                app.run()
                #else
                print("❌ Platform not supported yet")
                #endif
            }
        }
        """
    }
    
    private func createVanillaFrontend(at path: String, appName: String) throws {
        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(appName)</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    margin: 0;
                    padding: 40px;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    min-height: 100vh;
                }
                .container {
                    max-width: 800px;
                    margin: 0 auto;
                    text-align: center;
                }
                h1 { font-size: 3rem; margin-bottom: 20px; }
                p { font-size: 1.2rem; opacity: 0.9; }
                button {
                    background: rgba(255,255,255,0.2);
                    border: 1px solid rgba(255,255,255,0.3);
                    color: white;
                    padding: 12px 24px;
                    border-radius: 8px;
                    cursor: pointer;
                    font-size: 1rem;
                    margin: 10px;
                }
                button:hover { background: rgba(255,255,255,0.3); }
                #output {
                    background: rgba(0,0,0,0.2);
                    padding: 20px;
                    border-radius: 8px;
                    margin-top: 20px;
                    text-align: left;
                    font-family: monospace;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>⚡ \(appName)</h1>
                <p>Built with Swiftralino Framework</p>
                
                <div>
                    <button onclick="getSystemInfo()">Get System Info</button>
                    <button onclick="pingBackend()">Ping Backend</button>
                </div>
                
                <div id="output" style="display: none;"></div>
            </div>
            
            <script>
                // Connect to Swiftralino backend
                const ws = new WebSocket('ws://localhost:8080/bridge');
                
                ws.onopen = () => console.log('Connected to Swift backend');
                ws.onmessage = (event) => {
                    const data = JSON.parse(event.data);
                    showOutput(data);
                };
                
                function sendMessage(type, action, data) {
                    const message = {
                        id: Date.now().toString(),
                        type,
                        action,
                        data
                    };
                    ws.send(JSON.stringify(message));
                }
                
                function getSystemInfo() {
                    sendMessage('api', 'system', { operation: 'info' });
                }
                
                function pingBackend() {
                    sendMessage('system', 'ping');
                }
                
                function showOutput(data) {
                    const output = document.getElementById('output');
                    output.style.display = 'block';
                    output.textContent = JSON.stringify(data, null, 2);
                }
            </script>
        </body>
        </html>
        """
        
        try html.write(toFile: "\(path)/public/index.html", atomically: true, encoding: .utf8)
        print("🌐 Created vanilla HTML frontend")
    }
    
    private func createReactFrontend(at path: String, appName: String) throws {
        // Create package.json
        let packageJson = """
        {
          "name": "\(appName.lowercased())-frontend",
          "version": "0.1.0",
          "type": "module",
          "scripts": {
            "dev": "vite",
            "build": "vite build",
            "preview": "vite preview"
          },
          "dependencies": {
            "react": "^18.3.1",
            "react-dom": "^18.3.1"
          },
          "devDependencies": {
            "@types/react": "^18.3.3",
            "@types/react-dom": "^18.3.0",
            "@vitejs/plugin-react": "^4.3.1",
            "typescript": "^5.5.3",
            "vite": "^5.3.4"
          }
        }
        """
        
        try packageJson.write(toFile: "\(path)/frontend/package.json", atomically: true, encoding: .utf8)
        
        // Create other React files...
        let indexHtml = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(appName)</title>
        </head>
        <body>
            <div id="root"></div>
            <script type="module" src="/src/main.tsx"></script>
        </body>
        </html>
        """
        
        try indexHtml.write(toFile: "\(path)/frontend/index.html", atomically: true, encoding: .utf8)
        print("⚛️ Created React frontend template")
    }
    
    private func createVueFrontend(at path: String, appName: String) throws {
        // Similar implementation for Vue
        print("📱 Vue template not fully implemented yet - using React as fallback")
        try createReactFrontend(at: path, appName: appName)
    }
    
    private func createSvelteFrontend(at path: String, appName: String) throws {
        // Similar implementation for Svelte
        print("🔥 Svelte template not fully implemented yet - using React as fallback")
        try createReactFrontend(at: path, appName: appName)
    }
    
    // MARK: - Utility Methods
    
    private func runCommand(_ command: String, in directory: String) -> Int32 {
        let task = Process()
        task.currentDirectoryURL = URL(fileURLWithPath: directory)
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", command]
        
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus
        } catch {
            return 1
        }
    }
    
    private func isToolAvailable(_ tool: String) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = [tool]
        task.standardOutput = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }
}

// MARK: - Errors

enum ProjectError: Error, LocalizedError {
    case invalidName(String)
    case directoryExists(String)
    case templateNotFound(String)
    case creationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidName(let message):
            return "Invalid project name: \(message)"
        case .directoryExists(let message):
            return "Directory exists: \(message)"
        case .templateNotFound(let message):
            return "Template not found: \(message)"
        case .creationFailed(let message):
            return "Project creation failed: \(message)"
        }
    }
} 
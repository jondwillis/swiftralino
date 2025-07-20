import Foundation

// MARK: - Dev Server

public struct DevServer {
    public init() {}
    
    public func start(port: Int, openBrowser: Bool) throws {
        print("🔥 Starting development server on port \(port)")
        
        // Check if we're in a Swiftralino project
        guard let config = try? SwiftralinoConfig.load() else {
            throw CLIError.notInProject("No swiftralino.json found. Run 'swiftral create <project>' first.")
        }
        
        print("📋 Loaded configuration for: \(config.app.productName)")
        
        // Run pre-dev command if specified
        if let beforeDevCommand = config.build.beforeDevCommand {
            print("⚙️ Running before-dev command: \(beforeDevCommand)")
            let result = runCommand(beforeDevCommand)
            if result != 0 {
                print("⚠️ Before-dev command failed with exit code \(result)")
            }
        }
        
        // Start frontend development server in background
        try startFrontendDevServer(config: config)
        
        // Start Swift backend
        try startSwiftBackend(port: port)
        
        if openBrowser {
            openBrowserTo("http://localhost:\(port)")
        }
        
        print("✅ Development server started!")
        print("🌐 Frontend: \(config.build.devPath)")
        print("🦉 Backend: http://localhost:\(port)")
        print("Press Ctrl+C to stop")
        
        // Keep running until interrupted
        RunLoop.main.run()
    }
    
    private func startFrontendDevServer(config: SwiftralinoConfig) throws {
        // Detect frontend type and start appropriate dev server
        let frontendPath = detectFrontendPath()
        
        if FileManager.default.fileExists(atPath: "\(frontendPath)/package.json") {
            print("📦 Starting frontend development server...")
            
            // Start in background
            DispatchQueue.global().async {
                self.runFrontendDevServer(at: frontendPath)
            }
        } else {
            print("ℹ️ No frontend development server needed (vanilla HTML)")
        }
    }
    
    private func startSwiftBackend(port: Int) throws {
        print("🦉 Starting Swift backend...")
        
        let result = runCommand("swift run")
        if result != 0 {
            throw CLIError.buildFailed("Swift backend failed to start")
        }
    }
    
    private func runFrontendDevServer(at path: String) {
        let managers = [
            ("bun", "bun run dev"),
            ("npm", "npm run dev"),
            ("yarn", "yarn dev")
        ]
        
        for (manager, command) in managers {
            if isToolAvailable(manager) {
                _ = runCommand(command, in: path)
                break
            }
        }
    }
    
    private func detectFrontendPath() -> String {
        let candidates = ["frontend", "web", "ui", "public"]
        
        for candidate in candidates {
            if FileManager.default.fileExists(atPath: candidate) {
                return candidate
            }
        }
        
        return "frontend" // Default
    }
    
    private func openBrowserTo(_ url: String) {
        #if os(macOS)
        runCommand("open \(url)")
        #elseif os(Linux)
        runCommand("xdg-open \(url)")
        #endif
    }
}

// MARK: - App Builder

public struct AppBuilder {
    public init() {}
    
    public func build(debug: Bool, target: BuildCommand.BuildTarget) throws {
        guard let config = try? SwiftralinoConfig.load() else {
            throw CLIError.notInProject("No swiftralino.json found")
        }
        
        print("🔨 Building \(config.app.productName)...")
        
        // Run pre-build command if specified
        if let beforeBuildCommand = config.build.beforeBuildCommand {
            print("⚙️ Running before-build command: \(beforeBuildCommand)")
            let result = runCommand(beforeBuildCommand)
            if result != 0 {
                throw CLIError.buildFailed("Before-build command failed")
            }
        }
        
        // Build frontend
        try buildFrontend(config: config)
        
        // Build Swift backend
        try buildSwiftBackend(debug: debug, target: target)
        
        print("✅ Build completed successfully!")
    }
    
    private func buildFrontend(config: SwiftralinoConfig) throws {
        let frontendPath = detectFrontendPath()
        
        guard FileManager.default.fileExists(atPath: "\(frontendPath)/package.json") else {
            print("ℹ️ No frontend build needed")
            return
        }
        
        print("🌐 Building frontend...")
        
        let managers = [
            ("bun", "bun run build"),
            ("npm", "npm run build"),
            ("yarn", "yarn build")
        ]
        
        var built = false
        for (manager, command) in managers {
            if isToolAvailable(manager) {
                let result = runCommand(command, in: frontendPath)
                if result == 0 {
                    built = true
                    print("✅ Frontend built with \(manager)")
                    break
                }
            }
        }
        
        if !built {
            throw CLIError.buildFailed("Failed to build frontend")
        }
    }
    
    private func buildSwiftBackend(debug: Bool, target: BuildCommand.BuildTarget) throws {
        print("🦉 Building Swift backend...")
        
        let configuration = debug ? "debug" : "release"
        let buildCommand = "swift build -c \(configuration)"
        
        let result = runCommand(buildCommand)
        if result != 0 {
            throw CLIError.buildFailed("Swift build failed")
        }
        
        print("✅ Swift backend built successfully")
    }
    
    private func detectFrontendPath() -> String {
        let candidates = ["frontend", "web", "ui", "public"]
        
        for candidate in candidates {
            if FileManager.default.fileExists(atPath: candidate) {
                return candidate
            }
        }
        
        return "frontend"
    }
}

// MARK: - App Bundler

public struct AppBundler {
    public init() {}
    
    public func bundle(format: BundleCommand.BundleFormat) throws {
        guard let config = try? SwiftralinoConfig.load() else {
            throw CLIError.notInProject("No swiftralino.json found")
        }
        
        print("📦 Bundling \(config.app.productName) as \(format.rawValue)...")
        
        // Ensure the app is built first
        let builder = AppBuilder()
        try builder.build(debug: false, target: .current)
        
        // Create bundle based on format
        switch format {
        case .app:
            try createAppBundle(config: config)
        case .dmg:
            try createDMG(config: config)
        case .pkg:
            try createPKG(config: config)
        case .deb:
            try createDEB(config: config)
        case .appimage:
            try createAppImage(config: config)
        case .msi:
            try createMSI(config: config)
        }
        
        print("✅ Bundle created successfully!")
    }
    
    private func createAppBundle(config: SwiftralinoConfig) throws {
        #if os(macOS)
        print("🍎 Creating macOS .app bundle...")
        
        let appName = config.app.productName
        let bundlePath = "\(appName).app"
        let contentsPath = "\(bundlePath)/Contents"
        let macOSPath = "\(contentsPath)/MacOS"
        let resourcesPath = "\(contentsPath)/Resources"
        
        // Create bundle structure
        try FileManager.default.createDirectory(atPath: macOSPath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: resourcesPath, withIntermediateDirectories: true)
        
        // Copy executable
        let executableName = appName.lowercased()
        try FileManager.default.copyItem(
            atPath: ".build/release/\(executableName)",
            toPath: "\(macOSPath)/\(appName)"
        )
        
        // Create Info.plist
        let infoPlist = generateInfoPlist(config: config)
        try infoPlist.write(toFile: "\(contentsPath)/Info.plist", atomically: true, encoding: .utf8)
        
        // Copy frontend resources
        copyFrontendResources(to: resourcesPath)
        
        print("✅ Created \(bundlePath)")
        #else
        throw CLIError.platformNotSupported("App bundles are only supported on macOS")
        #endif
    }
    
    private func createDMG(config: SwiftralinoConfig) throws {
        #if os(macOS)
        print("💽 Creating DMG...")
        // Implementation for DMG creation
        throw CLIError.notImplemented("DMG creation not yet implemented")
        #else
        throw CLIError.platformNotSupported("DMG creation is only supported on macOS")
        #endif
    }
    
    private func createPKG(config: SwiftralinoConfig) throws {
        throw CLIError.notImplemented("PKG creation not yet implemented")
    }
    
    private func createDEB(config: SwiftralinoConfig) throws {
        throw CLIError.notImplemented("DEB creation not yet implemented")
    }
    
    private func createAppImage(config: SwiftralinoConfig) throws {
        throw CLIError.notImplemented("AppImage creation not yet implemented")
    }
    
    private func createMSI(config: SwiftralinoConfig) throws {
        throw CLIError.notImplemented("MSI creation not yet implemented")
    }
    
    private func generateInfoPlist(config: SwiftralinoConfig) -> String {
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleName</key>
            <string>\(config.app.productName)</string>
            <key>CFBundleDisplayName</key>
            <string>\(config.app.productName)</string>
            <key>CFBundleIdentifier</key>
            <string>\(config.app.identifier)</string>
            <key>CFBundleVersion</key>
            <string>\(config.app.version)</string>
            <key>CFBundleShortVersionString</key>
            <string>\(config.app.version)</string>
            <key>CFBundleExecutable</key>
            <string>\(config.app.productName)</string>
            <key>CFBundleIconFile</key>
            <string>AppIcon</string>
            <key>NSHighResolutionCapable</key>
            <true/>
            <key>LSMinimumSystemVersion</key>
            <string>12.0</string>
        </dict>
        </plist>
        """
    }
    
    private func copyFrontendResources(to path: String) {
        // Copy built frontend assets
        let distPaths = ["dist", "build", "public"]
        
        for distPath in distPaths {
            if FileManager.default.fileExists(atPath: distPath) {
                do {
                    try FileManager.default.copyItem(atPath: distPath, toPath: "\(path)/frontend")
                    break
                } catch {
                    continue
                }
            }
        }
    }
}

// MARK: - Plugin Manager

public struct PluginManager {
    public init() {}
    
    public func listPlugins() {
        guard let config = try? SwiftralinoConfig.load() else {
            print("❌ No swiftralino.json found")
            return
        }
        
        print("📋 Installed Plugins:")
        
        if config.plugins.isEmpty {
            print("  No plugins installed")
        } else {
            for plugin in config.plugins {
                print("  ✅ \(plugin)")
            }
        }
    }
    
    public func addPlugin(_ plugin: String) throws {
        var config = try SwiftralinoConfig.load()
        
        if config.plugins.contains(plugin) {
            print("ℹ️ Plugin '\(plugin)' is already installed")
            return
        }
        
        // Add plugin to configuration
        var newConfig = config
        var newPlugins = config.plugins
        newPlugins.append(plugin)
        
        // This is a bit hacky since the config struct is immutable
        // In a real implementation, we'd want mutable configuration
        print("📦 Adding plugin: \(plugin)")
        print("⚠️ Plugin system not fully implemented yet")
        
        // For now, just print what would happen
        print("✅ Plugin '\(plugin)' would be added to swiftralino.json")
    }
    
    public func removePlugin(_ plugin: String) throws {
        let config = try SwiftralinoConfig.load()
        
        if !config.plugins.contains(plugin) {
            print("ℹ️ Plugin '\(plugin)' is not installed")
            return
        }
        
        print("🗑️ Removing plugin: \(plugin)")
        print("⚠️ Plugin system not fully implemented yet")
        print("✅ Plugin '\(plugin)' would be removed from swiftralino.json")
    }
}

// MARK: - Utility Functions

func runCommand(_ command: String, in directory: String? = nil) -> Int32 {
    let task = Process()
    if let directory = directory {
        task.currentDirectoryURL = URL(fileURLWithPath: directory)
    }
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

func isToolAvailable(_ tool: String) -> Bool {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    task.arguments = [tool]
    task.standardOutput = Pipe()
    task.standardError = Pipe()
    
    do {
        try task.run()
        task.waitUntilExit()
        return task.terminationStatus == 0
    } catch {
        return false
    }
}

// MARK: - CLI Errors

enum CLIError: Error, LocalizedError {
    case notInProject(String)
    case buildFailed(String)
    case platformNotSupported(String)
    case notImplemented(String)
    case configurationError(String)
    
    var errorDescription: String? {
        switch self {
        case .notInProject(let message):
            return "Not in project: \(message)"
        case .buildFailed(let message):
            return "Build failed: \(message)"
        case .platformNotSupported(let message):
            return "Platform not supported: \(message)"
        case .notImplemented(let message):
            return "Not implemented: \(message)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        }
    }
} 
import Foundation
import Vapor

// MARK: - WebView Protocol

/// Protocol for platform-specific WebView implementations
public protocol WebViewManagerProtocol: Actor {
    func initialize() async
    func connectToBridge(url: String) async
    func cleanup() async
    func executeJavaScript(_ script: String) async -> Result<Any?, Error>
}

/// Main application actor that coordinates the Swiftralino framework components
/// Implements secure actor-based state management following Tauri's security model
@available(macOS 12.0, *)
public actor SwiftralinoApp {
    
    // MARK: - Private Properties
    
    private let configuration: AppConfiguration
    private var webServer: WebServer?
    private var webViewManager: WebViewManagerProtocol?
    private var isRunning = false
    private var launchTask: Task<Void, Error>?
    
    // MARK: - Initialization
    
    /// Initialize a new Swiftralino application
    /// - Parameters:
    ///   - configuration: Application configuration settings
    ///   - webViewManager: Platform-specific WebView manager implementation
    public init(configuration: AppConfiguration = .default, webViewManager: WebViewManagerProtocol? = nil) {
        self.configuration = configuration
        self.webViewManager = webViewManager
    }
    
    // MARK: - Public Interface
    
    /// Launch the application with WebSocket server and WebView
    public func launch() async throws {
        guard !isRunning else {
            throw SwiftralinoError.alreadyRunning
        }
        
        print("🚀 Starting Swiftralino application...")
        
        // Initialize and start the web server
        webServer = WebServer(configuration: configuration.server)
        try await webServer?.start()
        
        // Initialize WebView manager if available
        await webViewManager?.initialize()
        
        // Connect WebView to WebSocket server if available
        if webViewManager != nil {
            try await connectWebViewToServer()
        }
        
        isRunning = true
        print("✅ Swiftralino application started successfully")
        print("   WebSocket Server: \(configuration.server.host):\(configuration.server.port)")
        print("   WebView URL: \(configuration.webView.initialURL)")
    }
    
    /// Shutdown the application gracefully
    public func shutdown() async {
        guard isRunning else { return }
        
        print("🛑 Shutting down Swiftralino application...")
        isRunning = false
        
        // Cancel any running launch task
        launchTask?.cancel()
        launchTask = nil
        
        // Clean up in proper order - WebView first, then server
        await webViewManager?.cleanup()
        
        // Give time for any pending operations to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        await webServer?.stop()
        
        // Clear references
        webServer = nil
        
        print("✅ Swiftralino application shutdown complete")
    }
    
    /// Check if the application is currently running
    public func getIsRunning() -> Bool {
        return isRunning
    }
    
    /// Set the WebView manager (useful for dependency injection)
    /// - Parameter webViewManager: Platform-specific WebView manager implementation
    public func setWebViewManager(_ webViewManager: WebViewManagerProtocol) {
        self.webViewManager = webViewManager
    }
    
    // MARK: - Private Methods
    
    /// Connect WebView to WebSocket server
    private func connectWebViewToServer() async throws {
        guard let webViewManager = webViewManager else {
            throw SwiftralinoError.webViewNotAvailable
        }
        
        let bridgeURL = "ws://\(configuration.server.host):\(configuration.server.port)/bridge"
        await webViewManager.connectToBridge(url: bridgeURL)
    }
}

// MARK: - Configuration Types

/// Server configuration for the WebSocket server
public struct ServerConfiguration {
    public let host: String
    public let port: Int
    public let enableTLS: Bool
    
    public init(host: String = "127.0.0.1", port: Int = 8080, enableTLS: Bool = false) {
        self.host = host
        self.port = port
        self.enableTLS = enableTLS
    }
    
    public static let `default` = ServerConfiguration()
}

/// WebView configuration settings
public struct WebViewConfiguration {
    public let initialURL: String
    public let windowTitle: String
    public let windowWidth: Int
    public let windowHeight: Int
    public let enableDeveloperTools: Bool
    
    public init(
        initialURL: String = "http://127.0.0.1:8080",
        windowTitle: String = "Swiftralino App",
        windowWidth: Int = 1024,
        windowHeight: Int = 768,
        enableDeveloperTools: Bool = false
    ) {
        self.initialURL = initialURL
        self.windowTitle = windowTitle
        self.windowWidth = windowWidth
        self.windowHeight = windowHeight
        self.enableDeveloperTools = enableDeveloperTools
    }
    
    public static let `default` = WebViewConfiguration()
}

/// Main application configuration
public struct AppConfiguration {
    public let server: ServerConfiguration
    public let webView: WebViewConfiguration
    
    public init(server: ServerConfiguration = .default, webView: WebViewConfiguration = .default) {
        self.server = server
        self.webView = webView
    }
    
    public static let `default` = AppConfiguration()
}

// MARK: - Swiftralino Errors

/// Errors that can occur in the Swiftralino framework
public enum SwiftralinoError: LocalizedError {
    case alreadyRunning
    case webServerFailed(String)
    case webViewNotAvailable
    case configurationInvalid(String)
    
    public var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "Swiftralino application is already running"
        case .webServerFailed(let message):
            return "WebSocket server failed: \(message)"
        case .webViewNotAvailable:
            return "WebView is not available on this platform"
        case .configurationInvalid(let message):
            return "Configuration is invalid: \(message)"
        }
    }
}

// MARK: - WebView Errors

/// Errors that can occur with WebView operations
public enum WebViewError: LocalizedError {
    case notInitialized
    case scriptExecutionFailed(String)
    case platformNotSupported
    
    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "WebView is not initialized"
        case .scriptExecutionFailed(let message):
            return "JavaScript execution failed: \(message)"
        case .platformNotSupported:
            return "WebView is not supported on this platform"
        }
    }
} 
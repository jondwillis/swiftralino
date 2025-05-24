import Foundation
import Vapor

/// Main application actor that coordinates the Swiftralino framework components
/// Implements secure actor-based state management following Tauri's security model
@available(macOS 12.0, *)
public actor SwiftralinoApp {
    
    // MARK: - Private Properties
    
    private let configuration: AppConfiguration
    private var webServer: WebServer?
    private var webViewManager: WebViewManager?
    private var isRunning = false
    
    // MARK: - Initialization
    
    /// Initialize a new Swiftralino application
    /// - Parameter configuration: Application configuration settings
    public init(configuration: AppConfiguration = .default) {
        self.configuration = configuration
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
        
        // Initialize WebView manager
        webViewManager = WebViewManager(configuration: configuration.webView)
        await webViewManager?.initialize()
        
        // Connect WebView to WebSocket server
        try await connectWebViewToServer()
        
        isRunning = true
        print("✅ Swiftralino application started successfully")
        print("   WebSocket Server: \(configuration.server.host):\(configuration.server.port)")
        print("   WebView URL: \(configuration.webView.initialURL)")
    }
    
    /// Shutdown the application gracefully
    public func shutdown() async {
        guard isRunning else { return }
        
        print("🛑 Shutting down Swiftralino application...")
        
        await webViewManager?.cleanup()
        await webServer?.stop()
        
        isRunning = false
        print("✅ Swiftralino application shutdown complete")
    }
    
    /// Check if the application is currently running
    public func getIsRunning() -> Bool {
        return isRunning
    }
    
    // MARK: - Private Methods
    
    private func connectWebViewToServer() async throws {
        guard let webViewManager = webViewManager else {
            throw SwiftralinoError.componentNotInitialized
        }
        
        // Establish communication bridge between WebView and WebSocket server
        let bridgeURL = "ws://\(configuration.server.host):\(configuration.server.port)/bridge"
        await webViewManager.connectToBridge(url: bridgeURL)
    }
}

// MARK: - Supporting Types

/// Configuration for the Swiftralino application
public struct AppConfiguration {
    public let server: ServerConfiguration
    public let webView: WebViewConfiguration
    
    public init(server: ServerConfiguration = .default, 
                webView: WebViewConfiguration = .default) {
        self.server = server
        self.webView = webView
    }
    
    public static let `default` = AppConfiguration()
}

/// Configuration for the WebSocket server
public struct ServerConfiguration {
    public let host: String
    public let port: Int
    public let enableTLS: Bool
    
    public init(host: String = "127.0.0.1", 
                port: Int = 8080, 
                enableTLS: Bool = false) {
        self.host = host
        self.port = port
        self.enableTLS = enableTLS
    }
    
    public static let `default` = ServerConfiguration()
}

/// Configuration for the WebView component
public struct WebViewConfiguration {
    public let initialURL: String
    public let windowTitle: String
    public let windowWidth: Int
    public let windowHeight: Int
    public let enableDeveloperTools: Bool
    
    public init(initialURL: String = "http://127.0.0.1:8080",
                windowTitle: String = "Swiftralino App",
                windowWidth: Int = 1024,
                windowHeight: Int = 768,
                enableDeveloperTools: Bool = true) {
        self.initialURL = initialURL
        self.windowTitle = windowTitle
        self.windowWidth = windowWidth
        self.windowHeight = windowHeight
        self.enableDeveloperTools = enableDeveloperTools
    }
    
    public static let `default` = WebViewConfiguration()
}

/// Errors that can occur in the Swiftralino framework
public enum SwiftralinoError: Error, LocalizedError {
    case alreadyRunning
    case componentNotInitialized
    case webServerFailed(String)
    case webViewFailed(String)
    case communicationError(String)
    
    public var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "Application is already running"
        case .componentNotInitialized:
            return "Required component not initialized"
        case .webServerFailed(let message):
            return "Web server failed: \(message)"
        case .webViewFailed(let message):
            return "WebView failed: \(message)"
        case .communicationError(let message):
            return "Communication error: \(message)"
        }
    }
} 
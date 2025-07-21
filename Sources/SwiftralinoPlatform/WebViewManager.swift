import Foundation
import SwiftralinoCore

#if canImport(WebKit) && canImport(Cocoa)
import WebKit
import Cocoa
#endif

#if canImport(Distributed)
import Distributed
#endif

#if canImport(DistributedCluster)
import DistributedCluster
#endif

/// Manages WebView instances across different platforms
/// Provides abstraction layer for platform-specific WebView implementations
@available(macOS 14.0, *)
public actor WebViewManager: WebViewManagerProtocol {
    
    // MARK: - Private Properties
    
    private let configuration: WebViewConfiguration
    private var webView: PlatformWebView?
    private var bridgeURL: String?
    
    // NEW: Distributed capabilities
    private var distributedManager: DistributedPlatformManager?
    private var coordinator: DistributedPlatformCoordinator?
    
    // MARK: - Initialization
    
    /// Initialize the WebView manager
    /// - Parameter configuration: WebView configuration settings
    public init(configuration: WebViewConfiguration) {
        self.configuration = configuration
    }
    
    // MARK: - Public Interface
    
    /// Initialize the WebView for the current platform
    public func initialize() async {
        #if canImport(WebKit) && canImport(Cocoa)
        await initializeMacOSWebView()
        #elseif os(Linux)
        await initializeLinuxWebView()
        #elseif os(Windows)
        await initializeWindowsWebView()
        #else
        print("⚠️ WebView not supported on this platform")
        #endif
    }
    
    /// Connect the WebView to the WebSocket bridge
    /// - Parameter url: WebSocket bridge URL
    public func connectToBridge(url: String) async {
        bridgeURL = url
        await injectBridgeScript()
    }
    
    /// Clean up WebView resources
    public func cleanup() async {
        await distributedManager?.shutdown()
        await webView?.cleanup()
        webView = nil
    }
    
    /// Execute JavaScript in the WebView
    /// - Parameter script: JavaScript code to execute
    /// - Returns: Result of script execution
    public func executeJavaScript(_ script: String) async -> Result<Any?, Error> {
        guard let webView = webView else {
            return .failure(WebViewError.notInitialized)
        }
        return await webView.executeJavaScript(script)
    }
    
    // MARK: - NEW: Distributed Capabilities
    
    /// Initialize distributed capabilities
    /// - Parameter distributedConfig: Configuration for distributed clustering
    public func initializeDistributed(with distributedConfig: DistributedConfiguration) async throws {
        distributedManager = DistributedPlatformManager(configuration: distributedConfig)
        try await distributedManager?.initializeCluster()
        
        // Create and register coordinator
        coordinator = try await distributedManager?.createCoordinator()
        
        // Register this platform
        let platformInfo = PlatformInfo(
            id: UUID().uuidString,
            deviceName: getDeviceName(),
            platform: getCurrentPlatform(),
            version: getSystemVersion(),
            capabilities: ["webview", "javascript", "bridge"]
        )
        
        try await coordinator?.registerPlatform(platformInfo)
        print("🌐 WebView distributed capabilities initialized")
    }
    
    /// Execute JavaScript across all connected platforms
    /// - Parameter script: JavaScript to execute
    /// - Returns: Results from all platforms
    public func executeJavaScriptDistributed(_ script: String) async throws -> [CommandResult] {
        guard let coordinator = coordinator else {
            throw WebViewError.distributedNotInitialized
        }
        
        let command = DistributedCommand(
            id: UUID().uuidString,
            type: "javascript",
            payload: ["script": script]
        )
        
        return try await coordinator.executeAcrossPlatforms(command)
    }
    
    /// Share data with other platforms
    /// - Parameters:
    ///   - key: Data key
    ///   - data: Data to share
    public func shareData(key: String, data: Data) async throws {
        try await coordinator?.shareData(key: key, value: data)
    }
    
    /// Retrieve shared data from the distributed system
    /// - Parameter key: Data key
    /// - Returns: Shared data if available
    public func retrieveSharedData(key: String) async throws -> Data? {
        return try await coordinator?.retrieveData(key: key)
    }
    
    /// Get list of connected platforms
    public func getConnectedPlatforms() async throws -> [PlatformInfo] {
        guard let coordinator = coordinator else {
            return []
        }
        return try await coordinator.getConnectedPlatforms()
    }
    
    // MARK: - Private Methods
    
    #if canImport(WebKit) && canImport(Cocoa)
    private func initializeMacOSWebView() async {
        webView = MacOSWebView(configuration: configuration)
        await webView?.initialize()
        print("🖥️ macOS WebView initialized")
    }
    #endif
    
    #if os(Linux)
    private func initializeLinuxWebView() async {
        // Linux WebView implementation would go here
        // Using WebKitGTK through SwiftGtk bindings
        print("🐧 Linux WebView not yet implemented")
    }
    #endif
    
    #if os(Windows)
    private func initializeWindowsWebView() async {
        // Windows WebView implementation would go here
        // Would require WebView2 bindings or alternative approach
        print("🪟 Windows WebView not yet implemented")
    }
    #endif
    
    private func injectBridgeScript() async {
        guard let bridgeURL = bridgeURL else { return }
        
        let bridgeScript = """
        (function() {
            // Swiftralino Bridge - Connects JavaScript frontend to Swift backend
            class SwiftralinoBridge {
                constructor(wsUrl) {
                    this.wsUrl = wsUrl;
                    this.ws = null;
                    this.pendingRequests = new Map();
                    this.eventListeners = new Map();
                    this.connect();
                }
                
                connect() {
                    try {
                        this.ws = new WebSocket(this.wsUrl);
                        
                        this.ws.onopen = () => {
                            console.log('🔌 Connected to Swiftralino backend');
                            this.dispatchEvent('connected', {});
                        };
                        
                        this.ws.onmessage = (event) => {
                            try {
                                const message = JSON.parse(event.data);
                                this.handleMessage(message);
                            } catch (error) {
                                console.error('Failed to parse message:', error);
                            }
                        };
                        
                        this.ws.onclose = () => {
                            console.log('🔌 Disconnected from Swiftralino backend');
                            this.dispatchEvent('disconnected', {});
                            // Attempt reconnection after 1 second
                            setTimeout(() => this.connect(), 1000);
                        };
                        
                        this.ws.onerror = (error) => {
                            console.error('WebSocket error:', error);
                            this.dispatchEvent('error', { error });
                        };
                    } catch (error) {
                        console.error('Failed to create WebSocket:', error);
                    }
                }
                
                handleMessage(message) {
                    if (message.type === 'response' || message.type === 'error') {
                        // Handle API response
                        const resolve = this.pendingRequests.get(message.id);
                        if (resolve) {
                            this.pendingRequests.delete(message.id);
                            resolve(message);
                        }
                    } else {
                        // Handle events
                        this.dispatchEvent(message.action, message.data);
                    }
                }
                
                // Call Swift backend API
                async callAPI(action, parameters = {}) {
                    return new Promise((resolve, reject) => {
                        if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
                            reject(new Error('Not connected to backend'));
                            return;
                        }
                        
                        const id = this.generateId();
                        const message = {
                            id,
                            type: 'api',
                            action,
                            data: parameters
                        };
                        
                        this.pendingRequests.set(id, resolve);
                        this.ws.send(JSON.stringify(message));
                        
                        // Timeout after 30 seconds
                        setTimeout(() => {
                            if (this.pendingRequests.has(id)) {
                                this.pendingRequests.delete(id);
                                reject(new Error('Request timeout'));
                            }
                        }, 30000);
                    });
                }
                
                // NEW: Distributed capabilities
                async callDistributedAPI(action, parameters = {}) {
                    return this.callAPI('distributed.' + action, parameters);
                }
                
                // Execute JavaScript on all connected platforms
                async executeOnAllPlatforms(script) {
                    return this.callDistributedAPI('execute', { script });
                }
                
                // Share data across platforms
                async shareData(key, data) {
                    return this.callDistributedAPI('share', { key, data });
                }
                
                // Retrieve shared data
                async retrieveData(key) {
                    return this.callDistributedAPI('retrieve', { key });
                }
                
                // Get connected platforms
                async getConnectedPlatforms() {
                    return this.callDistributedAPI('platforms', {});
                }
                
                // Send system message
                sendSystemMessage(action, data = {}) {
                    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
                        console.warn('Cannot send system message: not connected');
                        return;
                    }
                    
                    const message = {
                        id: this.generateId(),
                        type: 'system',
                        action,
                        data
                    };
                    
                    this.ws.send(JSON.stringify(message));
                }
                
                // Event system
                addEventListener(event, listener) {
                    if (!this.eventListeners.has(event)) {
                        this.eventListeners.set(event, []);
                    }
                    this.eventListeners.get(event).push(listener);
                }
                
                removeEventListener(event, listener) {
                    const listeners = this.eventListeners.get(event);
                    if (listeners) {
                        const index = listeners.indexOf(listener);
                        if (index > -1) {
                            listeners.splice(index, 1);
                        }
                    }
                }
                
                dispatchEvent(event, data) {
                    const listeners = this.eventListeners.get(event);
                    if (listeners) {
                        listeners.forEach(listener => {
                            try {
                                listener(data);
                            } catch (error) {
                                console.error('Event listener error:', error);
                            }
                        });
                    }
                }
                
                generateId() {
                    return Math.random().toString(36).substr(2, 9);
                }
            }
            
            // Create global Swiftralino object
            window.Swiftralino = new SwiftralinoBridge('\(bridgeURL)');
            
            // Convenience methods
            window.Swiftralino.filesystem = {
                readDirectory: (path) => window.Swiftralino.callAPI('filesystem', { operation: 'readDirectory', path }),
                readFile: (path) => window.Swiftralino.callAPI('filesystem', { operation: 'readFile', path })
            };
            
            window.Swiftralino.system = {
                info: () => window.Swiftralino.callAPI('system', { operation: 'info' }),
                environment: () => window.Swiftralino.callAPI('system', { operation: 'environment' })
            };
            
            window.Swiftralino.process = {
                execute: (command, args = []) => window.Swiftralino.callAPI('process', { operation: 'execute', command, args })
            };
            
            // NEW: Distributed capabilities
            window.Swiftralino.distributed = {
                executeOnAll: (script) => window.Swiftralino.executeOnAllPlatforms(script),
                share: (key, data) => window.Swiftralino.shareData(key, data),
                retrieve: (key) => window.Swiftralino.retrieveData(key),
                platforms: () => window.Swiftralino.getConnectedPlatforms()
            };
            
            console.log('✅ Swiftralino bridge with distributed capabilities initialized');
        })();
        """
        
        let result = await executeJavaScript(bridgeScript)
        switch result {
        case .success:
            print("🌉 Bridge script with distributed capabilities injected successfully")
        case .failure(let error):
            print("❌ Failed to inject bridge script: \(error)")
        }
    }
    
    // Helper methods for platform detection
    private func getDeviceName() -> String {
        #if os(macOS)
        return Host.current().localizedName ?? "macOS Device"
        #elseif os(iOS)
        return UIDevice.current.name
        #else
        return "Unknown Device"
        #endif
    }
    
    private func getCurrentPlatform() -> String {
        #if os(macOS)
        return "macOS"
        #elseif os(iOS)
        return "iOS"
        #elseif os(Linux)
        return "Linux"
        #elseif os(Windows)
        return "Windows"
        #else
        return "Unknown"
        #endif
    }
    
    private func getSystemVersion() -> String {
        #if os(macOS)
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        #elseif os(iOS)
        return UIDevice.current.systemVersion
        #else
        return "Unknown"
        #endif
    }
}

// MARK: - Platform WebView Protocol

/// Protocol for platform-specific WebView implementations
protocol PlatformWebView {
    func initialize() async
    func cleanup() async
    func executeJavaScript(_ script: String) async -> Result<Any?, Error>
}

// MARK: - macOS WebView Implementation

#if canImport(WebKit) && canImport(Cocoa)

/// macOS-specific WebView implementation using WKWebView
@available(macOS 12.0, *)
class MacOSWebView: NSObject, PlatformWebView {
    
    private let configuration: WebViewConfiguration
    private var webView: WKWebView?
    private var window: NSWindow?
    
    init(configuration: WebViewConfiguration) {
        self.configuration = configuration
        super.init()
    }
    
    func initialize() async {
        await MainActor.run {
            // Create WKWebView configuration
            let webConfig = WKWebViewConfiguration()
            webConfig.preferences.setValue(true, forKey: "developerExtrasEnabled")
            
            // Create WebView
            webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1024, height: 768), configuration: webConfig)
            webView?.navigationDelegate = self
            
            // Create window
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: configuration.windowWidth, height: configuration.windowHeight),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            
            window?.title = configuration.windowTitle
            window?.contentView = webView
            window?.center()
            
            // Activate the application and bring window to foreground
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
            window?.orderFrontRegardless()
            
            // Ensure the window level is appropriate
            window?.level = .normal
            
            // Load initial URL
            if let url = URL(string: configuration.initialURL) {
                webView?.load(URLRequest(url: url))
            }
        }
    }
    
    func cleanup() async {
        await MainActor.run {
            window?.close()
            window = nil
            webView = nil
        }
    }
    
    func executeJavaScript(_ script: String) async -> Result<Any?, Error> {
        guard let webView = webView else {
            return .failure(WebViewError.notInitialized)
        }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                webView.evaluateJavaScript(script) { result, error in
                    if let error = error {
                        continuation.resume(returning: .failure(error))
                    } else {
                        continuation.resume(returning: .success(result))
                    }
                }
            }
        }
    }
}

// MARK: - WKNavigationDelegate

extension MacOSWebView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("🌐 WebView finished loading: \(webView.url?.absoluteString ?? "unknown")")
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ WebView navigation failed: \(error.localizedDescription)")
    }
}

#endif

// MARK: - WebView Errors

/// Errors that can occur in WebView operations
public enum WebViewError: Error, LocalizedError {
    case notInitialized
    case platformNotSupported
    case scriptExecutionFailed(String)
    case distributedNotInitialized
    
    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "WebView not initialized"
        case .platformNotSupported:
            return "WebView not supported on this platform"
        case .scriptExecutionFailed(let message):
            return "JavaScript execution failed: \(message)"
        case .distributedNotInitialized:
            return "Distributed capabilities not initialized"
        }
    }
} 
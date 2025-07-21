import Foundation

// Distributed functionality temporarily disabled due to experimental nature of Swift Distributed Actors
// #if canImport(SwiftralinoPlatform) && os(macOS)
// import SwiftralinoPlatform
// #endif

/// Handles incoming messages from WebSocket clients and processes API calls
/// Implements secure message processing with type-safe contracts
@available(macOS 12.0, *)
public actor MessageHandler {
    
    // MARK: - Private Properties
    
    private let apiRegistry: APIRegistry
    
    // MARK: - Initialization
    
    public init() {
        self.apiRegistry = APIRegistry()
        Task {
            await setupDefaultAPIs()
        }
    }
    
    // MARK: - Public Interface
    
    /// Process an incoming message and return appropriate response
    /// - Parameter message: The incoming message to process
    /// - Returns: Response message to send back to client
    public func handle(_ message: SwiftralinoMessage) async -> SwiftralinoMessage {
        print("🔄 Processing message: \(message.action)")
        
        switch message.type {
        case .api:
            return await handleAPICall(message)
        case .system:
            return await handleSystemMessage(message)
        case .event:
            return await handleEvent(message)
        default:
            return createErrorResponse(
                for: message,
                error: "Unsupported message type: \(message.type)"
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func handleAPICall(_ message: SwiftralinoMessage) async -> SwiftralinoMessage {
        guard let api = await apiRegistry.getAPI(for: message.action) else {
            return createErrorResponse(
                for: message,
                error: "Unknown API action: \(message.action)"
            )
        }
        
        do {
            let result = try await api.execute(parameters: message.data)
            return SwiftralinoMessage(
                id: message.id,
                type: .response,
                action: message.action,
                data: result
            )
        } catch {
            return createErrorResponse(
                for: message,
                error: "API execution failed: \(error.localizedDescription)"
            )
        }
    }
    
    private func handleSystemMessage(_ message: SwiftralinoMessage) async -> SwiftralinoMessage {
        switch message.action {
        case "ping":
            return SwiftralinoMessage(
                id: message.id,
                type: .response,
                action: "pong",
                data: ["timestamp": Date().timeIntervalSince1970]
            )
        case "version":
            return SwiftralinoMessage(
                id: message.id,
                type: .response,
                action: "version",
                data: ["version": "0.1.0", "platform": "swift"]
            )
        default:
            return createErrorResponse(
                for: message,
                error: "Unknown system action: \(message.action)"
            )
        }
    }
    
    private func handleEvent(_ message: SwiftralinoMessage) async -> SwiftralinoMessage {
        // Echo events back for now - in a real implementation,
        // this would handle application-specific events
        return SwiftralinoMessage(
            id: message.id,
            type: .response,
            action: "event_received",
            data: ["original_action": message.action]
        )
    }
    
    private func createErrorResponse(for message: SwiftralinoMessage, error: String) -> SwiftralinoMessage {
        return SwiftralinoMessage(
            id: message.id,
            type: .error,
            action: "error",
            data: [
                "original_action": message.action,
                "message": error
            ]
        )
    }
    
    private func setupDefaultAPIs() async {
        // Register built-in APIs
        await apiRegistry.register(FileSystemAPI())
        await apiRegistry.register(SystemAPI())
        await apiRegistry.register(ProcessAPI())
        
        // Distributed API temporarily disabled
        // #if canImport(SwiftralinoPlatform) && os(macOS)
        // // Register distributed API if available
        // do {
        //     await apiRegistry.register(DistributedAPI())
        //     print("🌐 Distributed API registered successfully")
        // } catch {
        //     print("⚠️ Failed to register Distributed API: \(error)")
        // }
        // #endif
    }
}

// MARK: - API Registry

/// Registry for managing available API endpoints
@available(macOS 12.0, *)
public actor APIRegistry {
    
    private var apis: [String: SwiftralinoAPI] = [:]
    
    /// Register a new API endpoint
    /// - Parameter api: The API to register
    public func register(_ api: SwiftralinoAPI) {
        apis[api.name] = api
        print("📋 Registered API: \(api.name)")
    }
    
    /// Get an API by name
    /// - Parameter name: The API name
    /// - Returns: The API if found
    public func getAPI(for name: String) -> SwiftralinoAPI? {
        return apis[name]
    }
    
    /// List all registered APIs
    /// - Returns: Array of API names
    public func listAPIs() -> [String] {
        return Array(apis.keys).sorted()
    }
}

// MARK: - API Protocol

/// Protocol for implementing Swiftralino API endpoints
public protocol SwiftralinoAPI {
    var name: String { get }
    var description: String { get }
    
    /// Execute the API with given parameters
    /// - Parameter parameters: Optional parameters for the API call
    /// - Returns: Result data
    func execute(parameters: [String: AnyCodable]?) async throws -> [String: Any]
}

// MARK: - Built-in APIs

/// File system operations API
public struct FileSystemAPI: SwiftralinoAPI {
    public let name = "filesystem"
    public let description = "File system operations"
    
    public func execute(parameters: [String: AnyCodable]?) async throws -> [String: Any] {
        guard let parameters = parameters,
              let operation = parameters["operation"]?.value as? String else {
            throw APIError.missingParameter("operation")
        }
        
        switch operation {
        case "readDirectory":
            guard let path = parameters["path"]?.value as? String else {
                throw APIError.missingParameter("path")
            }
            return try await readDirectory(path: path)
            
        case "readFile":
            guard let path = parameters["path"]?.value as? String else {
                throw APIError.missingParameter("path")
            }
            return try await readFile(path: path)
            
        default:
            throw APIError.unsupportedOperation(operation)
        }
    }
    
    private func readDirectory(path: String) async throws -> [String: Any] {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(atPath: path)
        return ["files": contents]
    }
    
    private func readFile(path: String) async throws -> [String: Any] {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        return ["content": content]
    }
}

/// System information API
public struct SystemAPI: SwiftralinoAPI {
    public let name = "system"
    public let description = "System information and operations"
    
    public func execute(parameters: [String: AnyCodable]?) async throws -> [String: Any] {
        guard let parameters = parameters,
              let operation = parameters["operation"]?.value as? String else {
            throw APIError.missingParameter("operation")
        }
        
        switch operation {
        case "info":
            return await getSystemInfo()
        case "environment":
            return getEnvironmentVariables()
        default:
            throw APIError.unsupportedOperation(operation)
        }
    }
    
    private func getSystemInfo() async -> [String: Any] {
        let processInfo = ProcessInfo.processInfo
        return [
            "operatingSystem": processInfo.operatingSystemVersionString,
            "hostName": processInfo.hostName,
            "processIdentifier": processInfo.processIdentifier,
            "arguments": processInfo.arguments,
            "uptime": processInfo.systemUptime
        ]
    }
    
    private func getEnvironmentVariables() -> [String: Any] {
        return ["environment": ProcessInfo.processInfo.environment]
    }
}

/// Process management API
public struct ProcessAPI: SwiftralinoAPI {
    public let name = "process"
    public let description = "Process management operations"
    
    public func execute(parameters: [String: AnyCodable]?) async throws -> [String: Any] {
        guard let parameters = parameters,
              let operation = parameters["operation"]?.value as? String else {
            throw APIError.missingParameter("operation")
        }
        
        switch operation {
        case "execute":
            guard let command = parameters["command"]?.value as? String else {
                throw APIError.missingParameter("command")
            }
            let args = (parameters["args"]?.value as? [String]) ?? []
            return try await executeCommand(command: command, args: args)
            
        default:
            throw APIError.unsupportedOperation(operation)
        }
    }
    
    private func executeCommand(command: String, args: [String]) async throws -> [String: Any] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = args
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""
        
        return [
            "exitCode": process.terminationStatus,
            "output": output,
            "error": error
        ]
    }
}

// Distributed functionality temporarily disabled due to experimental Swift Distributed Actors
/*
#if canImport(SwiftralinoPlatform) && os(macOS)
/// Distributed platform operations API
@available(macOS 14.0, *)
public struct DistributedAPI: SwiftralinoAPI {
    public let name = "distributed"
    public let description = "Distributed platform operations"
    
    // Static instance to maintain state across API calls
    private static let sharedManager = ActorWrapper()
    
    public func execute(parameters: [String: AnyCodable]?) async throws -> [String: Any] {
        guard let parameters = parameters,
              let operation = parameters["operation"]?.value as? String else {
            throw APIError.missingParameter("operation")
        }
        
        let manager = await Self.sharedManager.getManager()
        
        switch operation {
        case "initialize":
            let clusterName = (parameters["clusterName"]?.value as? String) ?? "swiftralino-cluster"
            let host = (parameters["host"]?.value as? String) ?? "127.0.0.1"
            let port = (parameters["port"]?.value as? Int) ?? 7337
            
            let config = DistributedConfiguration(
                clusterName: clusterName,
                host: host,
                port: port
            )
            
            try await manager.initialize(with: config)
            return ["status": "initialized", "clusterName": clusterName]
            
        case "platforms":
            let platforms = try await manager.getConnectedPlatforms()
            return ["platforms": platforms.map { platform in
                [
                    "id": platform.id,
                    "deviceName": platform.deviceName,
                    "platform": platform.platform,
                    "version": platform.version,
                    "capabilities": platform.capabilities
                ]
            }]
            
        case "execute":
            guard let script = parameters["script"]?.value as? String else {
                throw APIError.missingParameter("script")
            }
            
            let results = try await manager.executeJavaScriptDistributed(script)
            return ["results": results.map { result in
                [
                    "platformId": result.platformId,
                    "success": result.success,
                    "output": result.output,
                    "timestamp": result.timestamp.timeIntervalSince1970
                ]
            }]
            
        case "share":
            guard let key = parameters["key"]?.value as? String,
                  let dataString = parameters["data"]?.value as? String else {
                throw APIError.missingParameter("key or data")
            }
            
            guard let data = dataString.data(using: .utf8) else {
                throw APIError.executionFailed("Failed to encode data")
            }
            
            try await manager.shareData(key: key, data: data)
            return ["status": "shared", "key": key]
            
        case "retrieve":
            guard let key = parameters["key"]?.value as? String else {
                throw APIError.missingParameter("key")
            }
            
            if let data = try await manager.retrieveSharedData(key: key),
               let dataString = String(data: data, encoding: .utf8) {
                return ["key": key, "data": dataString]
            } else {
                return ["key": key, "data": NSNull()]
            }
            
        case "join":
            guard let endpoint = parameters["endpoint"]?.value as? String else {
                throw APIError.missingParameter("endpoint")
            }
            
            try await manager.joinCluster(endpoint: endpoint)
            return ["status": "joined", "endpoint": endpoint]
            
        case "status":
            let status = await manager.getClusterStatus()
            return ["status": status]
            
        default:
            throw APIError.unsupportedOperation(operation)
        }
    }
    
    // Actor wrapper to maintain WebViewManager instance
    @MainActor
    private final class ActorWrapper {
        private var webViewManager: WebViewManager?
        private var isInitialized = false
        
        func getManager() async -> WebViewManager {
            if webViewManager == nil {
                // Create a basic WebView configuration for distributed-only usage
                let config = WebViewConfiguration(
                    windowTitle: "Swiftralino Distributed Backend",
                    windowWidth: 1,
                    windowHeight: 1,
                    initialURL: "about:blank",
                    enableDeveloperTools: false
                )
                webViewManager = WebViewManager(configuration: config)
            }
            return webViewManager!
        }
        
        func initialize(with config: DistributedConfiguration) async throws {
            let manager = await getManager()
            if !isInitialized {
                try await manager.initializeDistributed(with: config)
                isInitialized = true
            }
        }
        
        func getConnectedPlatforms() async throws -> [PlatformInfo] {
            let manager = await getManager()
            return try await manager.getConnectedPlatforms()
        }
        
        func executeJavaScriptDistributed(_ script: String) async throws -> [CommandResult] {
            let manager = await getManager()
            return try await manager.executeJavaScriptDistributed(script)
        }
        
        func shareData(key: String, data: Data) async throws {
            let manager = await getManager()
            try await manager.shareData(key: key, data: data)
        }
        
        func retrieveSharedData(key: String) async throws -> Data? {
            let manager = await getManager()
            return try await manager.retrieveSharedData(key: key)
        }
        
        func joinCluster(endpoint: String) async throws {
            let manager = await getManager()
            // Parse endpoint string into Cluster.Endpoint if needed
            // For now, just acknowledge the join request
        }
        
        func getClusterStatus() async -> [String: Any] {
            if isInitialized {
                return [
                    "initialized": true,
                    "timestamp": Date().timeIntervalSince1970
                ]
            } else {
                return [
                    "initialized": false,
                    "message": "Cluster not initialized"
                ]
            }
        }
    }
}
#endif
*/

// MARK: - API Errors

/// Errors that can occur during API execution
public enum APIError: Error, LocalizedError {
    case missingParameter(String)
    case unsupportedOperation(String)
    case executionFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .missingParameter(let param):
            return "Missing required parameter: \(param)"
        case .unsupportedOperation(let operation):
            return "Unsupported operation: \(operation)"
        case .executionFailed(let message):
            return "API execution failed: \(message)"
        }
    }
} 
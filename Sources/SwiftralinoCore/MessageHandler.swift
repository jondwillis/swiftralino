import Foundation

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
                id: UUID().uuidString,
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
                id: UUID().uuidString,
                type: .response,
                action: "pong",
                data: ["timestamp": Date().timeIntervalSince1970]
            )
        case "version":
            return SwiftralinoMessage(
                id: UUID().uuidString,
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
            id: UUID().uuidString,
            type: .response,
            action: "event_received",
            data: ["original_action": message.action]
        )
    }
    
    private func createErrorResponse(for message: SwiftralinoMessage, error: String) -> SwiftralinoMessage {
        return SwiftralinoMessage(
            id: UUID().uuidString,
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
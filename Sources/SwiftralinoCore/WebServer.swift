import Foundation
import Vapor
import NIOCore
import NIOPosix
import NIOSSL

/// WebSocket server that handles communication between Swift backend and JavaScript frontend
/// Implements Neutralino's lightweight HTTP/WebSocket communication patterns
@available(macOS 12.0, *)
public actor WebServer {
    
    // MARK: - Private Properties
    
    private let configuration: ServerConfiguration
    private var app: Application?
    private var connectedClients: [WebSocket] = []
    private let messageHandler: MessageHandler
    
    // MARK: - Initialization
    
    /// Initialize the WebSocket server
    /// - Parameter configuration: Server configuration settings
    public init(configuration: ServerConfiguration) {
        self.configuration = configuration
        self.messageHandler = MessageHandler()
    }
    
    // MARK: - Public Interface
    
    /// Start the WebSocket server
    public func start() async throws {
        guard app == nil else {
            throw SwiftralinoError.webServerFailed("Server already running")
        }
        
        do {
            app = try await Application.make(.development)
            guard let app = app else {
                throw SwiftralinoError.webServerFailed("Failed to create Vapor application")
            }
            
            // Configure TLS if enabled
            if configuration.enableTLS {
                try configureTLS(app)
            }
            
            // Configure the server
            configureRoutes(app)
            configureWebSocketHandlers(app)
            
            // Start server
            let scheme = configuration.enableTLS ? "https" : "http"
            try await app.server.start(address: .hostname(configuration.host, port: configuration.port))
            print("📡 WebSocket server started on \(scheme)://\(configuration.host):\(configuration.port)")
            
        } catch {
            throw SwiftralinoError.webServerFailed("Failed to start server: \(error.localizedDescription)")
        }
    }
    
    /// Stop the WebSocket server
    public func stop() async {
        guard let app = app else { return }
        
        print("📡 Stopping WebSocket server...")
        
        // Close all connected WebSocket clients first
        await closeAllConnections()
        
        // Give clients time to disconnect cleanly
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Shutdown the server gracefully
        await app.server.shutdown()
        
        // Clear the app reference
        self.app = nil
        
        print("📡 WebSocket server stopped")
    }
    
    /// Broadcast a message to all connected clients
    /// - Parameter message: The message to broadcast
    public func broadcast(message: SwiftralinoMessage) async {
        let jsonData = try? JSONEncoder().encode(message)
        let jsonString = jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        
        for client in connectedClients {
            try? await client.send(jsonString)
        }
    }
    
    // MARK: - Private Methods
    
    private func configureRoutes(_ app: Application) {
        // Serve static files for the frontend
        app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
        
        // Root route - serve index.html
        app.get { req async throws -> Response in
            let path = app.directory.publicDirectory + "index.html"
            guard let data = FileManager.default.contents(atPath: path) else {
                throw Abort(.notFound, reason: "index.html not found")
            }
            return Response(status: .ok, headers: ["Content-Type": "text/html"], body: .init(data: data))
        }
        
        // Health check endpoint
        app.get("health") { req async in
            return ["status": "ok", "timestamp": "\(Date().timeIntervalSince1970)"]
        }
        
        // API endpoints for Swift backend functionality
        app.get("api", "system", "info") { [weak self] req async -> [String: String] in
            let info = await self?.handleSystemInfo() ?? [:]
            // Convert to [String: String] for proper encoding
            return info.mapValues { "\($0)" }
        }
    }
    
    private func configureWebSocketHandlers(_ app: Application) {
        // WebSocket bridge endpoint
        app.webSocket("bridge") { [weak self] req, ws in
            await self?.handleWebSocketConnection(ws)
        }
    }
    
    private func handleWebSocketConnection(_ ws: WebSocket) async {
        // Add client to connected array
        connectedClients.append(ws)
        
        print("🔌 WebSocket client connected (total: \(connectedClients.count))")
        
        // Send welcome message
        let welcomeMessage = SwiftralinoMessage(
            id: UUID().uuidString,
            type: .system,
            action: "welcome",
            data: ["message": "Connected to Swiftralino backend"]
        )
        
        if let jsonData = try? JSONEncoder().encode(welcomeMessage),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            try? await ws.send(jsonString)
        }
        
        // Handle incoming messages
        ws.onText { [weak self] ws, text in
            await self?.handleIncomingMessage(text, from: ws)
        }
        
        // Handle client disconnection
        ws.onClose.whenComplete { [weak self] _ in
            Task {
                await self?.handleClientDisconnection(ws)
            }
        }
    }
    
    private func handleIncomingMessage(_ text: String, from ws: WebSocket) async {
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(SwiftralinoMessage.self, from: data) else {
            await sendErrorResponse(to: ws, error: "Invalid message format")
            return
        }
        
        print("📨 Received message: \(message.action) (\(message.type))")
        
        // Process message through handler
        let response = await messageHandler.handle(message)
        
        // Send response back to client
        if let jsonData = try? JSONEncoder().encode(response),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            try? await ws.send(jsonString)
        }
    }
    
    private func handleClientDisconnection(_ ws: WebSocket) async {
        connectedClients.removeAll { $0 === ws }
        print("🔌 WebSocket client disconnected (total: \(connectedClients.count))")
    }
    
    private func closeAllConnections() async {
        let clients = connectedClients
        connectedClients.removeAll()
        
        for client in clients {
            do {
                try await client.close(code: .goingAway)
            } catch {
                // Ignore errors during cleanup
            }
        }
    }
    
    private func sendErrorResponse(to ws: WebSocket, error: String) async {
        let errorMessage = SwiftralinoMessage(
            id: UUID().uuidString,
            type: .error,
            action: "error",
            data: ["message": error]
        )
        
        if let jsonData = try? JSONEncoder().encode(errorMessage),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            try? await ws.send(jsonString)
        }
    }
    
    private func handleSystemInfo() async -> [String: Any] {
        return [
            "platform": "swift",
            "version": "0.1.0",
            "timestamp": Date().timeIntervalSince1970,
            "processId": ProcessInfo.processInfo.processIdentifier
        ]
    }
    
    // MARK: - TLS Configuration
    
    private func configureTLS(_ app: Application) throws {
        // Certificate paths in order of preference
        let certPaths = [
            ("/app/ssl/cert.pem", "/app/ssl/key.pem"),
            ("/app/ssl/server.crt", "/app/ssl/server.key"),
            // Let's Encrypt path
            ("/etc/letsencrypt/live/\(ProcessInfo.processInfo.environment["DOMAIN"] ?? "localhost")/cert.pem",
             "/etc/letsencrypt/live/\(ProcessInfo.processInfo.environment["DOMAIN"] ?? "localhost")/privkey.pem"),
        ]
        
        for (certPath, keyPath) in certPaths {
            if FileManager.default.fileExists(atPath: certPath) && 
               FileManager.default.fileExists(atPath: keyPath) {
                
                print("🔒 Configuring TLS with certificate: \(certPath)")
                
                do {
                    // Configure Vapor for TLS
                    let certificate = try NIOSSLCertificate(file: certPath, format: .pem)
                    let privateKey = try NIOSSLPrivateKey(file: keyPath, format: .pem)
                    
                    app.http.server.configuration.tlsConfiguration = TLSConfiguration.makeServerConfiguration(
                        certificateChain: [.certificate(certificate)],
                        privateKey: .privateKey(privateKey)
                    )
                    
                    return
                } catch {
                    print("⚠️ Failed to load certificate \(certPath): \(error)")
                    continue
                }
            }
        }
        
        throw SwiftralinoError.webServerFailed("TLS enabled but no valid certificates found. Please provide cert.pem and key.pem in /app/ssl/ or disable TLS.")
    }
}

// MARK: - Message Types

/// Standard message format for communication between Swift backend and JavaScript frontend
public struct SwiftralinoMessage: Codable {
    public let id: String
    public let type: MessageType
    public let action: String
    public let data: [String: AnyCodable]?
    
    public init(id: String, type: MessageType, action: String, data: [String: Any]? = nil) {
        self.id = id
        self.type = type
        self.action = action
        self.data = data?.mapValues { AnyCodable($0) }
    }
}

/// Message types for categorizing communication
public enum MessageType: String, Codable {
    case system = "system"
    case api = "api"
    case event = "event"
    case response = "response"
    case error = "error"
}

/// Type-erased wrapper for JSON encoding/decoding
public struct AnyCodable: Codable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
} 
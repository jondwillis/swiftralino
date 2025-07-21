import Testing
import Foundation
@testable import SwiftralinoCore

@Suite("Core Swiftralino Tests")
struct SwiftralinoTests {
    
    // MARK: - Configuration Tests
    
    @Test("App configuration has correct defaults")
    @available(macOS 12.0, *)
    func appConfigurationDefaults() {
        let config = AppConfiguration.default
        
        #expect(config.server.host == "127.0.0.1")
        #expect(config.server.port == 8080)
        #expect(config.server.enableTLS == true)
        
        #expect(config.webView.windowTitle == "Swiftralino App")
        #expect(config.webView.windowWidth == 1024)
        #expect(config.webView.windowHeight == 768)
        #expect(config.webView.enableDeveloperTools == false)
    }
    
    @Test("Server configuration with custom values", 
          arguments: [
            ("localhost", 3000, true),
            ("0.0.0.0", 8080, false),
            ("192.168.1.1", 9999, true)
          ])
    @available(macOS 12.0, *)
    func serverConfigurationCustomValues(host: String, port: Int, enableTLS: Bool) {
        let serverConfig = ServerConfiguration(host: host, port: port, enableTLS: enableTLS)
        
        #expect(serverConfig.host == host)
        #expect(serverConfig.port == port)
        #expect(serverConfig.enableTLS == enableTLS)
    }
    
    // MARK: - Message Handling Tests
    
    @Test("SwiftralinoMessage encodes and decodes correctly")
    @available(macOS 12.0, *)
    func swiftralinoMessageEncoding() throws {
        let message = SwiftralinoMessage(
            id: "test-123",
            type: .api,
            action: "filesystem",
            data: ["operation": "readDirectory", "path": "/tmp"]
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        
        #expect(!data.isEmpty)
        
        let decoder = JSONDecoder()
        let decodedMessage = try decoder.decode(SwiftralinoMessage.self, from: data)
        
        #expect(decodedMessage.id == "test-123")
        #expect(decodedMessage.type == .api)
        #expect(decodedMessage.action == "filesystem")
        #expect(decodedMessage.data != nil)
    }
    
    @Test("MessageHandler processes ping messages correctly")
    @available(macOS 12.0, *)
    func messageHandlerCreation() async {
        let handler = MessageHandler()
        
        // Test system ping message
        let pingMessage = SwiftralinoMessage(
            id: "ping-test",
            type: .system,
            action: "ping"
        )
        
        let response = await handler.handle(pingMessage)
        
        #expect(response.type == .response)
        #expect(response.action == "pong")
        #expect(response.data?["timestamp"] != nil)
    }
    
    @Test("Different message types", arguments: [
        MessageType.system,
        MessageType.api,
        MessageType.response,
        MessageType.error
    ])
    @available(macOS 12.0, *)
    func messageTypeHandling(messageType: MessageType) throws {
        let message = SwiftralinoMessage(
            id: "test-\(messageType)",
            type: messageType,
            action: "test"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SwiftralinoMessage.self, from: data)
        
        #expect(decoded.type == messageType)
    }
    
    // MARK: - API Tests
    
    @Test("API Registry manages APIs correctly")
    @available(macOS 12.0, *)
    func apiRegistryFunctionality() async {
        let registry = APIRegistry()
        let testAPI = TestAPI()
        
        await registry.register(testAPI)
        
        let retrievedAPI = await registry.getAPI(for: "test")
        #expect(retrievedAPI != nil)
        
        let apiList = await registry.listAPIs()
        #expect(apiList.contains("test"))
    }
    
    @Test("FileSystem API executes readDirectory operation", .timeLimit(.minutes(1)))
    @available(macOS 12.0, *)
    func fileSystemAPIExecution() async throws {
        let api = FileSystemAPI()
        
        // Test readDirectory operation
        let parameters: [String: AnyCodable] = [
            "operation": AnyCodable("readDirectory"),
            "path": AnyCodable("/tmp")
        ]
        
        do {
            let result = try await api.execute(parameters: parameters)
            #expect(result["files"] != nil)
        } catch {
            // It's okay if /tmp doesn't exist or isn't accessible
            #expect(error is APIError)
        }
    }
    
    @Test("System API returns system information")
    @available(macOS 12.0, *)
    func systemAPIExecution() async throws {
        let api = SystemAPI()
        
        // Test info operation
        let parameters: [String: AnyCodable] = [
            "operation": AnyCodable("info")
        ]
        
        let result = try await api.execute(parameters: parameters)
        
        #expect(result["operatingSystem"] != nil)
        #expect(result["hostName"] != nil)
        #expect(result["processIdentifier"] != nil)
    }
    
    // MARK: - App Integration Tests
    
    @Test("SwiftralinoApp initializes with correct state")
    @available(macOS 12.0, *)
    func swiftralinoAppInitialization() async {
        let config = AppConfiguration(
            server: ServerConfiguration(host: "127.0.0.1", port: 9999),
            webView: WebViewConfiguration(windowTitle: "Test App")
        )
        
        let app = SwiftralinoApp(configuration: config)
        let isRunning = await app.getIsRunning()
        
        #expect(isRunning == false, "App should not be running initially")
    }
    
    // MARK: - Data Type Tests
    
    @Test("AnyCodable handles various data types", 
          arguments: [
            ("string", AnyCodable("test string")),
            ("int", AnyCodable(42)),
            ("bool", AnyCodable(true)),
            ("array", AnyCodable(["item1", "item2"])),
            ("double", AnyCodable(3.14))
          ])
    @available(macOS 12.0, *)
    func anyCodableTypeHandling(name: String, value: AnyCodable) throws {
        let testData: [String: AnyCodable] = [name: value]
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(testData)
        
        #expect(!data.isEmpty)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode([String: AnyCodable].self, from: data)
        
        #expect(decoded[name] != nil)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("WebView errors provide correct descriptions", 
          arguments: [
            (WebViewError.notInitialized, "WebView not initialized"),
            (WebViewError.scriptExecutionFailed("syntax error"), "JavaScript execution failed: syntax error")
          ])
    @available(macOS 12.0, *)
    func webViewErrorHandling(error: WebViewError, expectedDescription: String) {
        #expect(error.localizedDescription == expectedDescription)
    }
    
    @Test("API errors provide correct descriptions",
          arguments: [
            (APIError.missingParameter("path"), "Missing required parameter: path"),
            (APIError.unsupportedOperation("invalidOp"), "Unsupported operation: invalidOp"),
            (APIError.executionFailed("timeout"), "API execution failed: timeout")
          ])
    @available(macOS 12.0, *)
    func apiErrorHandling(error: APIError, expectedDescription: String) {
        #expect(error.localizedDescription == expectedDescription)
    }
}

// MARK: - Test Support Types

private struct TestAPI: SwiftralinoAPI {
    let name = "test"
    let description = "Test API for unit testing"
    
    func execute(parameters: [String: AnyCodable]?) async throws -> [String: Any] {
        return [
            "message": "Test API executed successfully",
            "timestamp": Date().timeIntervalSince1970
        ]
    }
} 
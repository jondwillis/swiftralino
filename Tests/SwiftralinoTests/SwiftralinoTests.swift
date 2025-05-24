import XCTest
@testable import SwiftralinoCore

@available(macOS 12.0, *)
final class SwiftralinoTests: XCTestCase {
    
    func testAppConfigurationDefaults() {
        let config = AppConfiguration.default
        
        XCTAssertEqual(config.server.host, "127.0.0.1")
        XCTAssertEqual(config.server.port, 8080)
        XCTAssertFalse(config.server.enableTLS)
        
        XCTAssertEqual(config.webView.windowTitle, "Swiftralino App")
        XCTAssertEqual(config.webView.windowWidth, 1024)
        XCTAssertEqual(config.webView.windowHeight, 768)
        XCTAssertTrue(config.webView.enableDeveloperTools)
    }
    
    func testSwiftralinoMessageEncoding() throws {
        let message = SwiftralinoMessage(
            id: "test-123",
            type: .api,
            action: "filesystem",
            data: ["operation": "readDirectory", "path": "/tmp"]
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        
        XCTAssertFalse(data.isEmpty)
        
        let decoder = JSONDecoder()
        let decodedMessage = try decoder.decode(SwiftralinoMessage.self, from: data)
        
        XCTAssertEqual(decodedMessage.id, "test-123")
        XCTAssertEqual(decodedMessage.type, .api)
        XCTAssertEqual(decodedMessage.action, "filesystem")
        XCTAssertNotNil(decodedMessage.data)
    }
    
    func testMessageHandlerCreation() async {
        let handler = MessageHandler()
        
        // Test system ping message
        let pingMessage = SwiftralinoMessage(
            id: "ping-test",
            type: .system,
            action: "ping"
        )
        
        let response = await handler.handle(pingMessage)
        
        XCTAssertEqual(response.type, .response)
        XCTAssertEqual(response.action, "pong")
        XCTAssertNotNil(response.data?["timestamp"])
    }
    
    func testAPIRegistryFunctionality() async {
        let registry = APIRegistry()
        let testAPI = TestAPI()
        
        await registry.register(testAPI)
        
        let retrievedAPI = await registry.getAPI(for: "test")
        XCTAssertNotNil(retrievedAPI)
        
        let apiList = await registry.listAPIs()
        XCTAssertTrue(apiList.contains("test"))
    }
    
    func testFileSystemAPIExecution() async throws {
        let api = FileSystemAPI()
        
        // Test readDirectory operation
        let parameters: [String: AnyCodable] = [
            "operation": AnyCodable("readDirectory"),
            "path": AnyCodable("/tmp")
        ]
        
        do {
            let result = try await api.execute(parameters: parameters)
            XCTAssertNotNil(result["files"])
        } catch {
            // It's okay if /tmp doesn't exist or isn't accessible
            XCTAssertTrue(error is APIError)
        }
    }
    
    func testSystemAPIExecution() async throws {
        let api = SystemAPI()
        
        // Test info operation
        let parameters: [String: AnyCodable] = [
            "operation": AnyCodable("info")
        ]
        
        let result = try await api.execute(parameters: parameters)
        
        XCTAssertNotNil(result["operatingSystem"])
        XCTAssertNotNil(result["hostName"])
        XCTAssertNotNil(result["processIdentifier"])
    }
    
    func testSwiftralinoAppInitialization() async {
        let config = AppConfiguration(
            server: ServerConfiguration(host: "127.0.0.1", port: 9999),
            webView: WebViewConfiguration(windowTitle: "Test App")
        )
        
        let app = SwiftralinoApp(configuration: config)
        let isRunning = await app.getIsRunning()
        
        XCTAssertFalse(isRunning, "App should not be running initially")
    }
    
    func testAnyCodableTypeHandling() throws {
        // Test various types
        let stringValue = AnyCodable("test string")
        let intValue = AnyCodable(42)
        let boolValue = AnyCodable(true)
        let arrayValue = AnyCodable(["item1", "item2"])
        
        let testData: [String: AnyCodable] = [
            "string": stringValue,
            "int": intValue,
            "bool": boolValue,
            "array": arrayValue
        ]
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(testData)
        
        XCTAssertFalse(data.isEmpty)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode([String: AnyCodable].self, from: data)
        
        XCTAssertEqual(decoded.count, 4)
    }
    
    func testWebViewErrorHandling() {
        let error = WebViewError.notInitialized
        XCTAssertEqual(error.localizedDescription, "WebView not initialized")
        
        let scriptError = WebViewError.scriptExecutionFailed("syntax error")
        XCTAssertEqual(scriptError.localizedDescription, "JavaScript execution failed: syntax error")
    }
    
    func testAPIErrorHandling() {
        let missingParamError = APIError.missingParameter("path")
        XCTAssertEqual(missingParamError.localizedDescription, "Missing required parameter: path")
        
        let unsupportedError = APIError.unsupportedOperation("invalidOp")
        XCTAssertEqual(unsupportedError.localizedDescription, "Unsupported operation: invalidOp")
    }
}

// MARK: - Test Helper APIs

struct TestAPI: SwiftralinoAPI {
    let name = "test"
    let description = "Test API for unit testing"
    
    func execute(parameters: [String: AnyCodable]?) async throws -> [String: Any] {
        return [
            "message": "Test API executed successfully",
            "timestamp": Date().timeIntervalSince1970
        ]
    }
} 
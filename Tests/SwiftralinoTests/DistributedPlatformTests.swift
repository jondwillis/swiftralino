import XCTest
@testable import SwiftralinoPlatform
@testable import SwiftralinoCore

#if canImport(DistributedCluster)
import DistributedCluster
#endif

@available(macOS 14.0, *)
final class DistributedPlatformTests: XCTestCase {
    
    private var distributedManager: DistributedPlatformManager!
    private var testConfiguration: DistributedConfiguration!
    
    override func setUp() async throws {
        try await super.setUp()
        
        testConfiguration = DistributedConfiguration(
            clusterName: "test-cluster-\(UUID().uuidString.prefix(8))",
            host: "127.0.0.1",
            port: Int.random(in: 17000...18000), // Random port to avoid conflicts
            discovery: nil,
            tls: nil
        )
        
        distributedManager = DistributedPlatformManager(configuration: testConfiguration)
    }
    
    override func tearDown() async throws {
        if distributedManager != nil {
            await distributedManager.shutdown()
            distributedManager = nil
        }
        try await super.tearDown()
    }
    
    // MARK: - Configuration Tests
    
    func testDistributedConfigurationDefaults() {
        let config = DistributedConfiguration(clusterName: "test")
        
        XCTAssertEqual(config.clusterName, "test")
        XCTAssertEqual(config.host, "127.0.0.1")
        XCTAssertEqual(config.port, 7337)
        XCTAssertNil(config.discovery)
        XCTAssertNil(config.tls)
    }
    
    func testDistributedConfigurationCustomValues() {
        let config = DistributedConfiguration(
            clusterName: "custom-cluster",
            host: "192.168.1.100",
            port: 9999
        )
        
        XCTAssertEqual(config.clusterName, "custom-cluster")
        XCTAssertEqual(config.host, "192.168.1.100")
        XCTAssertEqual(config.port, 9999)
    }
    
    // MARK: - Platform Manager Tests
    
    func testDistributedPlatformManagerInitialization() {
        XCTAssertNotNil(distributedManager)
        XCTAssertEqual(distributedManager.configuration.clusterName, testConfiguration.clusterName)
    }
    
    func testClusterInitialization() async throws {
        #if canImport(DistributedCluster)
        // This test will only run when DistributedCluster is available
        do {
            try await distributedManager.initializeCluster()
            // If we get here, initialization succeeded
            XCTAssertTrue(true, "Cluster initialization succeeded")
        } catch DistributedPlatformError.distributedClusterNotAvailable {
            // Expected when DistributedCluster isn't available
            throw XCTSkip("DistributedCluster framework not available in test environment")
        } catch {
            XCTFail("Unexpected error during cluster initialization: \(error)")
        }
        #else
        // Test that proper error is thrown when DistributedCluster isn't available
        do {
            try await distributedManager.initializeCluster()
            XCTFail("Should have thrown distributedClusterNotAvailable error")
        } catch DistributedPlatformError.distributedClusterNotAvailable {
            // Expected
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        #endif
    }
    
    func testCreateCoordinatorWithoutInitializedCluster() async throws {
        // Should fail without initialized cluster
        do {
            _ = try await distributedManager.createCoordinator()
            XCTFail("Should have thrown clusterNotInitialized error")
        } catch DistributedPlatformError.clusterNotInitialized {
            XCTAssertTrue(true, "Correctly threw clusterNotInitialized error")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    #if canImport(DistributedCluster)
    func testFullClusterWorkflow() async throws {
        do {
            // Initialize cluster
            try await distributedManager.initializeCluster()
            
            // Create coordinator
            let coordinator = try await distributedManager.createCoordinator()
            XCTAssertNotNil(coordinator, "Coordinator should be created successfully")
            
            // Test platform registration
            let platformInfo = PlatformInfo(
                id: "test-platform-1",
                deviceName: "Test Device",
                platform: "macOS",
                version: "14.0",
                capabilities: ["webview", "javascript", "testing"]
            )
            
            try await coordinator?.registerPlatform(platformInfo)
            
            // Verify platform is registered
            let connectedPlatforms = try await coordinator?.getConnectedPlatforms() ?? []
            XCTAssertEqual(connectedPlatforms.count, 1)
            XCTAssertEqual(connectedPlatforms.first?.id, "test-platform-1")
            XCTAssertEqual(connectedPlatforms.first?.deviceName, "Test Device")
            
            // Test command execution
            let command = DistributedCommand(
                id: "test-command-1",
                type: "test",
                payload: ["message": "Hello from test"]
            )
            
            let results = try await coordinator?.executeAcrossPlatforms(command) ?? []
            XCTAssertEqual(results.count, 1)
            XCTAssertTrue(results.first?.success ?? false)
            
            // Test data sharing
            let testData = "Hello, distributed world!".data(using: .utf8)!
            try await coordinator?.shareData(key: "test-key", value: testData)
            
            let retrievedData = try await coordinator?.retrieveData(key: "test-key")
            XCTAssertEqual(retrievedData, testData)
            
            // Test platform unregistration
            try await coordinator?.unregisterPlatform("test-platform-1")
            let platformsAfterUnregister = try await coordinator?.getConnectedPlatforms() ?? []
            XCTAssertEqual(platformsAfterUnregister.count, 0)
            
        } catch DistributedPlatformError.distributedClusterNotAvailable {
            throw XCTSkip("DistributedCluster framework not available")
        }
    }
    #endif
    
    // MARK: - Supporting Types Tests
    
    func testPlatformInfoCodable() throws {
        let platformInfo = PlatformInfo(
            id: "test-id",
            deviceName: "Test Device",
            platform: "macOS",
            version: "14.0",
            capabilities: ["capability1", "capability2"]
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(platformInfo)
        XCTAssertFalse(data.isEmpty)
        
        let decoder = JSONDecoder()
        let decodedPlatform = try decoder.decode(PlatformInfo.self, from: data)
        
        XCTAssertEqual(decodedPlatform.id, platformInfo.id)
        XCTAssertEqual(decodedPlatform.deviceName, platformInfo.deviceName)
        XCTAssertEqual(decodedPlatform.platform, platformInfo.platform)
        XCTAssertEqual(decodedPlatform.version, platformInfo.version)
        XCTAssertEqual(decodedPlatform.capabilities, platformInfo.capabilities)
    }
    
    func testPlatformInfoHashable() {
        let platform1 = PlatformInfo(
            id: "same-id",
            deviceName: "Device 1",
            platform: "macOS",
            version: "14.0",
            capabilities: []
        )
        
        let platform2 = PlatformInfo(
            id: "same-id",
            deviceName: "Device 2", // Different name but same ID
            platform: "iOS",
            version: "17.0",
            capabilities: []
        )
        
        let platform3 = PlatformInfo(
            id: "different-id",
            deviceName: "Device 3",
            platform: "macOS",
            version: "14.0",
            capabilities: []
        )
        
        // Same ID should be equal
        XCTAssertEqual(platform1, platform2)
        
        // Different ID should not be equal
        XCTAssertNotEqual(platform1, platform3)
        
        // Test in Set
        let platformSet: Set<PlatformInfo> = [platform1, platform2, platform3]
        XCTAssertEqual(platformSet.count, 2) // platform1 and platform2 should be deduplicated
    }
    
    func testDistributedCommandCodable() throws {
        let command = DistributedCommand(
            id: "test-command",
            type: "test-type",
            payload: ["key1": "value1", "key2": "value2"]
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(command)
        XCTAssertFalse(data.isEmpty)
        
        let decoder = JSONDecoder()
        let decodedCommand = try decoder.decode(DistributedCommand.self, from: data)
        
        XCTAssertEqual(decodedCommand.id, command.id)
        XCTAssertEqual(decodedCommand.type, command.type)
        XCTAssertEqual(decodedCommand.payload, command.payload)
        XCTAssertEqual(decodedCommand.timestamp.timeIntervalSince1970, 
                      command.timestamp.timeIntervalSince1970, accuracy: 1.0)
    }
    
    func testCommandResultCodable() throws {
        let result = CommandResult(
            platformId: "platform-123",
            success: true,
            output: "Command executed successfully",
            timestamp: Date()
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(result)
        XCTAssertFalse(data.isEmpty)
        
        let decoder = JSONDecoder()
        let decodedResult = try decoder.decode(CommandResult.self, from: data)
        
        XCTAssertEqual(decodedResult.platformId, result.platformId)
        XCTAssertEqual(decodedResult.success, result.success)
        XCTAssertEqual(decodedResult.output, result.output)
        XCTAssertEqual(decodedResult.timestamp.timeIntervalSince1970,
                      result.timestamp.timeIntervalSince1970, accuracy: 1.0)
    }
    
    // MARK: - Error Tests
    
    func testDistributedPlatformErrors() {
        let errors: [DistributedPlatformError] = [
            .distributedClusterNotAvailable,
            .clusterNotInitialized,
            .coordinatorNotFound,
            .commandExecutionFailed("Test error message")
        ]
        
        let expectedDescriptions = [
            "DistributedCluster framework not available",
            "Cluster system not initialized",
            "No distributed coordinator found",
            "Command execution failed: Test error message"
        ]
        
        for (error, expectedDescription) in zip(errors, expectedDescriptions) {
            XCTAssertEqual(error.localizedDescription, expectedDescription)
        }
    }
    
    // MARK: - Integration Tests
    
    func testWebViewManagerDistributedIntegration() async throws {
        let webViewConfig = WebViewConfiguration(
            initialURL: "http://localhost:3000",
            windowTitle: "Test WebView",
            windowWidth: 800,
            windowHeight: 600
        )
        
        let webViewManager = WebViewManager(configuration: webViewConfig)
        
        // Test that distributed initialization fails without proper setup
        do {
            try await webViewManager.initializeDistributed(with: testConfiguration)
            // If this succeeds, check that we can get empty platforms list
            let platforms = try await webViewManager.getConnectedPlatforms()
            XCTAssertTrue(platforms.isEmpty, "Should start with empty platforms list")
        } catch DistributedPlatformError.distributedClusterNotAvailable {
            throw XCTSkip("DistributedCluster framework not available")
        } catch {
            XCTFail("Unexpected error in WebView distributed initialization: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testPlatformRegistrationPerformance() async throws {
        #if canImport(DistributedCluster)
        do {
            try await distributedManager.initializeCluster()
            guard let coordinator = try await distributedManager.createCoordinator() else {
                throw XCTSkip("Could not create coordinator")
            }
            
            // Measure performance of registering multiple platforms
            measure {
                let expectation = XCTestExpectation(description: "Platform registration")
                
                Task {
                    for i in 0..<100 {
                        let platformInfo = PlatformInfo(
                            id: "platform-\(i)",
                            deviceName: "Device \(i)",
                            platform: "macOS",
                            version: "14.0",
                            capabilities: ["test"]
                        )
                        
                        try await coordinator.registerPlatform(platformInfo)
                    }
                    expectation.fulfill()
                }
                
                wait(for: [expectation], timeout: 10.0)
            }
        } catch DistributedPlatformError.distributedClusterNotAvailable {
            throw XCTSkip("DistributedCluster framework not available")
        }
        #else
        throw XCTSkip("DistributedCluster framework not available")
        #endif
    }
    
    func testDataSharingPerformance() async throws {
        #if canImport(DistributedCluster)
        do {
            try await distributedManager.initializeCluster()
            guard let coordinator = try await distributedManager.createCoordinator() else {
                throw XCTSkip("Could not create coordinator")
            }
            
            let testData = Data(repeating: 0x42, count: 1024) // 1KB test data
            
            measure {
                let expectation = XCTestExpectation(description: "Data sharing")
                
                Task {
                    for i in 0..<50 {
                        try await coordinator.shareData(key: "test-key-\(i)", value: testData)
                    }
                    expectation.fulfill()
                }
                
                wait(for: [expectation], timeout: 10.0)
            }
        } catch DistributedPlatformError.distributedClusterNotAvailable {
            throw XCTSkip("DistributedCluster framework not available")
        }
        #else
        throw XCTSkip("DistributedCluster framework not available")
        #endif
    }
} 
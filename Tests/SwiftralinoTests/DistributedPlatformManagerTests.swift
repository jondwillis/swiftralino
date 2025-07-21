import XCTest
@testable import SwiftralinoPlatform
@testable import SwiftralinoCore

#if canImport(DistributedCluster)
import DistributedCluster
#endif

@available(macOS 14.0, iOS 16.0, *)
final class DistributedPlatformManagerTests: XCTestCase {
    
    var distributedManager: DistributedPlatformManager?
    
    override func setUp() async throws {
        try await super.setUp()
        
        let config = DistributedConfiguration(
            clusterName: "test-cluster",
            host: "127.0.0.1",
            port: 7338 // Use different port for tests
        )
        distributedManager = DistributedPlatformManager(configuration: config)
    }
    
    override func tearDown() async throws {
        await distributedManager?.shutdown()
        distributedManager = nil
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
    
    // MARK: - Platform Info Tests
    
    func testPlatformInfoCreation() {
        let platformInfo = PlatformInfo(
            id: "test-platform",
            deviceName: "Test Device",
            platform: "macOS",
            version: "14.0.0",
            capabilities: ["webview", "javascript"]
        )
        
        XCTAssertEqual(platformInfo.id, "test-platform")
        XCTAssertEqual(platformInfo.deviceName, "Test Device")
        XCTAssertEqual(platformInfo.platform, "macOS")
        XCTAssertEqual(platformInfo.version, "14.0.0")
        XCTAssertEqual(platformInfo.capabilities, ["webview", "javascript"])
    }
    
    func testPlatformInfoEquality() {
        let platform1 = PlatformInfo(
            id: "platform-1",
            deviceName: "Device 1",
            platform: "macOS",
            version: "14.0",
            capabilities: ["webview"]
        )
        
        let platform2 = PlatformInfo(
            id: "platform-1",
            deviceName: "Device 1",
            platform: "macOS", 
            version: "14.0",
            capabilities: ["webview"]
        )
        
        let platform3 = PlatformInfo(
            id: "platform-2",
            deviceName: "Device 2", 
            platform: "macOS",
            version: "14.0",
            capabilities: ["webview"]
        )
        
        XCTAssertEqual(platform1, platform2)
        XCTAssertNotEqual(platform1, platform3)
    }
    
    // MARK: - Distributed Command Tests
    
    func testDistributedCommandCreation() {
        let command = DistributedCommand(
            id: "cmd-123",
            type: "javascript",
            payload: ["script": "console.log('test')"]
        )
        
        XCTAssertEqual(command.id, "cmd-123")
        XCTAssertEqual(command.type, "javascript")
        XCTAssertEqual(command.payload["script"], "console.log('test')")
        XCTAssertNotNil(command.timestamp)
    }
    
    func testCommandResultCreation() {
        let result = CommandResult(
            platformId: "platform-1",
            success: true,
            output: "Command executed successfully",
            timestamp: Date()
        )
        
        XCTAssertEqual(result.platformId, "platform-1")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.output, "Command executed successfully")
    }
    
    // MARK: - Manager Initialization Tests
    
    func testDistributedManagerInitialization() {
        let config = DistributedConfiguration(clusterName: "init-test")
        let manager = DistributedPlatformManager(configuration: config)
        
        XCTAssertNotNil(manager)
    }
    
    // MARK: - Cluster Management Tests
    
    func testInitializeCluster() async throws {
        #if canImport(DistributedCluster)
        guard let manager = distributedManager else {
            XCTFail("Manager not initialized")
            return
        }
        
        do {
            try await manager.initializeCluster()
            // If we reach here without throwing, the cluster was initialized
            XCTAssertTrue(true, "Cluster initialized successfully")
        } catch DistributedPlatformError.distributedClusterNotAvailable {
            // This is expected in test environments without distributed cluster support
            throw XCTSkip("DistributedCluster framework not available in test environment")
        } catch {
            XCTFail("Unexpected error during cluster initialization: \(error)")
        }
        #else
        throw XCTSkip("DistributedCluster not available")
        #endif
    }
    
    func testCreateCoordinatorWithoutInitializedCluster() async throws {
        guard let manager = distributedManager else {
            XCTFail("Manager not initialized")
            return
        }
        
        do {
            _ = try await manager.createCoordinator()
            XCTFail("Should have thrown clusterNotInitialized error")
        } catch DistributedPlatformError.clusterNotInitialized {
            // This is expected
            XCTAssertTrue(true, "Correctly threw clusterNotInitialized error")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testFindCoordinatorsWithoutInitializedCluster() async {
        guard let manager = distributedManager else {
            XCTFail("Manager not initialized")
            return
        }
        
        let coordinators = await manager.findCoordinators()
        XCTAssertNil(coordinators, "Should return nil when cluster not initialized")
    }
    
    // MARK: - Coordinator Tests (when distributed cluster is available)
    
    #if canImport(DistributedCluster)
    func testCoordinatorLifecycle() async throws {
        guard let manager = distributedManager else {
            XCTFail("Manager not initialized")
            return
        }
        
        do {
            try await manager.initializeCluster()
            
            let coordinator = try await manager.createCoordinator()
            XCTAssertNotNil(coordinator, "Coordinator should be created")
            
            // Test platform registration
            let platformInfo = PlatformInfo(
                id: "test-platform",
                deviceName: "Test Device",
                platform: "macOS",
                version: "14.0.0",
                capabilities: ["webview", "javascript", "bridge"]
            )
            
            try await coordinator?.registerPlatform(platformInfo)
            
            let connectedPlatforms = try await coordinator?.getConnectedPlatforms() ?? []
            XCTAssertTrue(connectedPlatforms.contains(platformInfo), "Platform should be registered")
            
            // Test platform unregistration
            try await coordinator?.unregisterPlatform("test-platform")
            
            let platformsAfterUnregister = try await coordinator?.getConnectedPlatforms() ?? []
            XCTAssertFalse(platformsAfterUnregister.contains(platformInfo), "Platform should be unregistered")
            
        } catch DistributedPlatformError.distributedClusterNotAvailable {
            throw XCTSkip("DistributedCluster framework not available in test environment")
        }
    }
    
    func testDataSharing() async throws {
        guard let manager = distributedManager else {
            XCTFail("Manager not initialized")
            return
        }
        
        do {
            try await manager.initializeCluster()
            let coordinator = try await manager.createCoordinator()
            
            guard let coordinator = coordinator else {
                XCTFail("Failed to create coordinator")
                return
            }
            
            let testData = "Hello, distributed world!".data(using: .utf8)!
            let testKey = "test-message"
            
            // Share data
            try await coordinator.shareData(key: testKey, value: testData)
            
            // Retrieve data
            let retrievedData = try await coordinator.retrieveData(key: testKey)
            XCTAssertNotNil(retrievedData, "Data should be retrievable")
            XCTAssertEqual(retrievedData, testData, "Retrieved data should match original")
            
        } catch DistributedPlatformError.distributedClusterNotAvailable {
            throw XCTSkip("DistributedCluster framework not available in test environment")
        }
    }
    
    func testExecuteAcrossPlatforms() async throws {
        guard let manager = distributedManager else {
            XCTFail("Manager not initialized")
            return
        }
        
        do {
            try await manager.initializeCluster()
            let coordinator = try await manager.createCoordinator()
            
            guard let coordinator = coordinator else {
                XCTFail("Failed to create coordinator")
                return
            }
            
            // Register a test platform
            let platformInfo = PlatformInfo(
                id: "test-platform",
                deviceName: "Test Device",
                platform: "macOS",
                version: "14.0.0",
                capabilities: ["webview", "javascript"]
            )
            
            try await coordinator.registerPlatform(platformInfo)
            
            // Create and execute a distributed command
            let command = DistributedCommand(
                id: UUID().uuidString,
                type: "javascript",
                payload: ["script": "console.log('test')"]
            )
            
            let results = try await coordinator.executeAcrossPlatforms(command)
            XCTAssertFalse(results.isEmpty, "Should have results from registered platforms")
            XCTAssertEqual(results.count, 1, "Should have one result for one registered platform")
            XCTAssertEqual(results[0].platformId, "test-platform", "Result should be from the registered platform")
            
        } catch DistributedPlatformError.distributedClusterNotAvailable {
            throw XCTSkip("DistributedCluster framework not available in test environment")
        }
    }
    #endif
    
    // MARK: - Error Handling Tests
    
    func testDistributedPlatformErrors() {
        let error1 = DistributedPlatformError.distributedClusterNotAvailable
        XCTAssertEqual(error1.localizedDescription, "DistributedCluster framework not available")
        
        let error2 = DistributedPlatformError.clusterNotInitialized
        XCTAssertEqual(error2.localizedDescription, "Cluster system not initialized")
        
        let error3 = DistributedPlatformError.coordinatorNotFound
        XCTAssertEqual(error3.localizedDescription, "No distributed coordinator found")
        
        let error4 = DistributedPlatformError.commandExecutionFailed("test error")
        XCTAssertEqual(error4.localizedDescription, "Command execution failed: test error")
    }
    
    // MARK: - Performance Tests
    
    func testManagerShutdownPerformance() async throws {
        guard let manager = distributedManager else {
            XCTFail("Manager not initialized")
            return
        }
        
        // Measure shutdown time
        let startTime = CFAbsoluteTimeGetCurrent()
        await manager.shutdown()
        let shutdownTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Shutdown should be relatively quick (under 2 seconds)
        XCTAssertLessThan(shutdownTime, 2.0, "Shutdown should complete within 2 seconds")
    }
    
    // MARK: - JSON Serialization Tests
    
    func testPlatformInfoJSONSerialization() throws {
        let platformInfo = PlatformInfo(
            id: "json-test",
            deviceName: "JSON Test Device",
            platform: "macOS",
            version: "14.0.0",
            capabilities: ["webview", "javascript", "bridge"]
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(platformInfo)
        
        XCTAssertFalse(data.isEmpty)
        
        let decoder = JSONDecoder()
        let decodedInfo = try decoder.decode(PlatformInfo.self, from: data)
        
        XCTAssertEqual(decodedInfo, platformInfo)
    }
    
    func testDistributedCommandJSONSerialization() throws {
        let command = DistributedCommand(
            id: "json-cmd-test",
            type: "javascript", 
            payload: ["script": "console.log('JSON test')"]
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(command)
        
        XCTAssertFalse(data.isEmpty)
        
        let decoder = JSONDecoder()
        let decodedCommand = try decoder.decode(DistributedCommand.self, from: data)
        
        XCTAssertEqual(decodedCommand.id, command.id)
        XCTAssertEqual(decodedCommand.type, command.type)
        XCTAssertEqual(decodedCommand.payload, command.payload)
    }
    
    func testCommandResultJSONSerialization() throws {
        let result = CommandResult(
            platformId: "json-result-test",
            success: true,
            output: "JSON test output",
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
    }
} 
import Testing
import Foundation
@testable import SwiftralinoPlatform
@testable import SwiftralinoCore

#if canImport(DistributedCluster)
import DistributedCluster
#endif

@Suite("Distributed Platform Tests")
struct DistributedPlatformTests {
    
    // Helper method to create test configuration
    private func createTestConfiguration() -> DistributedConfiguration {
        return DistributedConfiguration(
            clusterName: "test-cluster-\(UUID().uuidString.prefix(8))",
            host: "127.0.0.1",
            port: Int.random(in: 17000...18000), // Random port to avoid conflicts
            discovery: nil,
            tls: nil
        )
    }
    
    // MARK: - Configuration Tests
    
    @Test("Distributed configuration uses correct defaults")
    @available(macOS 14.0, *)
    func distributedConfigurationDefaults() {
        let config = DistributedConfiguration(clusterName: "test")
        
        #expect(config.clusterName == "test")
        #expect(config.host == "127.0.0.1")
        #expect(config.port == 7337)
        #expect(config.discovery == nil)
        #expect(config.tls == nil)
    }
    
    @Test("Distributed configuration accepts custom values", 
          arguments: [
            ("custom-cluster", "192.168.1.100", 9999),
            ("test-cluster", "localhost", 8080),
            ("prod-cluster", "0.0.0.0", 7337)
          ])
    @available(macOS 14.0, *)
    func distributedConfigurationCustomValues(clusterName: String, host: String, port: Int) {
        let config = DistributedConfiguration(
            clusterName: clusterName,
            host: host,
            port: port
        )
        
        #expect(config.clusterName == clusterName)
        #expect(config.host == host)
        #expect(config.port == port)
    }
    
    // MARK: - Platform Manager Tests
    
    @Test("DistributedPlatformManager initializes correctly")
    @available(macOS 14.0, *)
    func distributedPlatformManagerInitialization() {
        let testConfiguration = DistributedConfiguration(clusterName: "test")
        let distributedManager = DistributedPlatformManager(configuration: testConfiguration)
        
        #expect(distributedManager.configuration.clusterName == testConfiguration.clusterName)
    }
    
    @Test("Creating coordinator fails without initialized cluster")
    @available(macOS 14.0, *)
    func createCoordinatorWithoutInitializedCluster() async throws {
        let testConfiguration = DistributedConfiguration(clusterName: "test")
        let distributedManager = DistributedPlatformManager(configuration: testConfiguration)
        
        defer {
            Task {
                await distributedManager.shutdown()
            }
        }
        
        // Should fail without initialized cluster
        do {
            _ = try await distributedManager.createCoordinator()
            Issue.record("Expected clusterNotInitialized error")
        } catch DistributedPlatformError.clusterNotInitialized {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Cluster Operations Tests
    
    @Test("Cluster initialization works when DistributedCluster is available", 
          .timeLimit(.minutes(1)), .tags(.distributed, .integration))
    @available(macOS 14.0, *)
    func clusterInitialization() async throws {
        let testConfiguration = createTestConfiguration()
        let distributedManager = DistributedPlatformManager(configuration: testConfiguration)
        
        defer {
            Task {
                await distributedManager.shutdown()
            }
        }
        
        #if canImport(DistributedCluster)
        // This test will only run when DistributedCluster is available
        do {
            try await distributedManager.initializeCluster()
            // If we get here, initialization succeeded
        } catch DistributedPlatformError.distributedClusterNotAvailable {
            // Expected when DistributedCluster isn't available
            withKnownIssue("DistributedCluster framework not available in test environment") {
                // Skip this test
            }
            return
        } catch {
            Issue.record("Unexpected error during cluster initialization: \(error)")
        }
        #else
        do {
            try await distributedManager.initializeCluster()
            Issue.record("Should have thrown distributedClusterNotAvailable error")
        } catch DistributedPlatformError.distributedClusterNotAvailable {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #endif
    }
    
    #if canImport(DistributedCluster)
    @Test("Full cluster workflow with platform registration and coordination", 
          .timeLimit(.minutes(1)), .tags(.integration, .slow))
    @available(macOS 14.0, *)
    func fullClusterWorkflow() async throws {
        let testConfiguration = createTestConfiguration()
        let distributedManager = DistributedPlatformManager(configuration: testConfiguration)
        
        defer {
            Task {
                await distributedManager.shutdown()
            }
        }
        
        do {
            // Initialize cluster
            try await distributedManager.initializeCluster()
            
            // Create coordinator
            let coordinator = try await distributedManager.createCoordinator()
            #expect(coordinator != nil, "Coordinator should be created successfully")
            
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
            #expect(connectedPlatforms.count == 1)
            #expect(connectedPlatforms.first?.id == "test-platform-1")
            #expect(connectedPlatforms.first?.deviceName == "Test Device")
            
            // Test command execution
            let command = DistributedCommand(
                id: "test-command-1",
                type: "test",
                payload: ["message": "Hello from test"]
            )
            
            let results = try await coordinator?.executeAcrossPlatforms(command) ?? []
            #expect(results.count == 1)
            #expect(results.first?.success == true)
            
            // Test data sharing
            let testData = "Hello, distributed world!".data(using: .utf8)!
            try await coordinator?.shareData(key: "test-key", value: testData)
            
            let retrievedData = try await coordinator?.retrieveData(key: "test-key")
            #expect(retrievedData == testData)
            
            // Test platform unregistration
            try await coordinator?.unregisterPlatform("test-platform-1")
            let platformsAfterUnregister = try await coordinator?.getConnectedPlatforms() ?? []
            #expect(platformsAfterUnregister.count == 0)
            
        } catch DistributedPlatformError.distributedClusterNotAvailable {
            withKnownIssue("DistributedCluster framework not available") {
                // Skip this test
            }
        }
    }
    #endif
    
    // MARK: - Data Type Tests
    
    @Test("PlatformInfo encodes and decodes correctly")
    @available(macOS 14.0, *)
    func platformInfoCodable() throws {
        let platformInfo = PlatformInfo(
            id: "test-id",
            deviceName: "Test Device",
            platform: "macOS",
            version: "14.0",
            capabilities: ["capability1", "capability2"]
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(platformInfo)
        #expect(!data.isEmpty)
        
        let decoder = JSONDecoder()
        let decodedPlatform = try decoder.decode(PlatformInfo.self, from: data)
        
        #expect(decodedPlatform.id == platformInfo.id)
        #expect(decodedPlatform.deviceName == platformInfo.deviceName)
        #expect(decodedPlatform.platform == platformInfo.platform)
        #expect(decodedPlatform.version == platformInfo.version)
        #expect(decodedPlatform.capabilities == platformInfo.capabilities)
    }
    
    @Test("PlatformInfo implements Hashable correctly based on ID",
          arguments: [
            ("same-id", "same-id", true),
            ("different-id-1", "different-id-2", false),
            ("test-123", "test-123", true)
          ])
    @available(macOS 14.0, *)
    func platformInfoHashable(id1: String, id2: String, shouldBeEqual: Bool) {
        let platform1 = PlatformInfo(
            id: id1,
            deviceName: "Device 1",
            platform: "macOS",
            version: "14.0",
            capabilities: []
        )
        
        let platform2 = PlatformInfo(
            id: id2,
            deviceName: "Device 2", // Different name but potentially same ID
            platform: "iOS",
            version: "17.0",
            capabilities: []
        )
        
        if shouldBeEqual {
            #expect(platform1 == platform2)
            #expect(platform1.hashValue == platform2.hashValue)
        } else {
            #expect(platform1 != platform2)
        }
    }
    
    @Test("DistributedCommand encodes and decodes correctly",
          arguments: [
            ("test-command", "test-type", ["key1": "value1"]),
            ("ping", "system", ["timestamp": "1234567890"]),
            ("execute", "javascript", ["code": "console.log('hello')"])
          ])
    @available(macOS 14.0, *)
    func distributedCommandCodable(id: String, type: String, payload: [String: String]) throws {
        let command = DistributedCommand(
            id: id,
            type: type,
            payload: payload
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(command)
        #expect(!data.isEmpty)
        
        let decoder = JSONDecoder()
        let decodedCommand = try decoder.decode(DistributedCommand.self, from: data)
        
        #expect(decodedCommand.id == command.id)
        #expect(decodedCommand.type == command.type)
        #expect(decodedCommand.payload == command.payload)
        #expect(abs(decodedCommand.timestamp.timeIntervalSince1970 - command.timestamp.timeIntervalSince1970) < 1.0)
    }
    
    @Test("CommandResult encodes and decodes correctly",
          arguments: [
            ("platform-123", true, "Success"),
            ("platform-456", false, "Error occurred"),
            ("platform-789", true, "Command completed")
          ])
    @available(macOS 14.0, *)
    func commandResultCodable(platformId: String, success: Bool, output: String) throws {
        let result = CommandResult(
            platformId: platformId,
            success: success,
            output: output,
            timestamp: Date()
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(result)
        #expect(!data.isEmpty)
        
        let decoder = JSONDecoder()
        let decodedResult = try decoder.decode(CommandResult.self, from: data)
        
        #expect(decodedResult.platformId == result.platformId)
        #expect(decodedResult.success == result.success)
        #expect(decodedResult.output == result.output)
        #expect(abs(decodedResult.timestamp.timeIntervalSince1970 - result.timestamp.timeIntervalSince1970) < 1.0)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("DistributedPlatformError provides correct error descriptions",
          arguments: [
            (DistributedPlatformError.distributedClusterNotAvailable, "DistributedCluster framework not available"),
            (DistributedPlatformError.clusterNotInitialized, "Cluster system not initialized"),
            (DistributedPlatformError.coordinatorNotFound, "No distributed coordinator found"),
            (DistributedPlatformError.commandExecutionFailed("Test error message"), "Command execution failed: Test error message")
          ])
    @available(macOS 14.0, *)
    func distributedPlatformErrors(error: DistributedPlatformError, expectedDescription: String) {
        #expect(error.localizedDescription == expectedDescription)
    }
    
    // MARK: - Integration Tests
    
    @Test("WebViewManager integrates with distributed platform", 
          .timeLimit(.minutes(1)), .tags(.integration))
    @available(macOS 14.0, *)
    func webViewManagerDistributedIntegration() async throws {
        let webViewConfig = WebViewConfiguration(
            initialURL: "http://localhost:3000",
            windowTitle: "Test WebView",
            windowWidth: 800,
            windowHeight: 600
        )
        
        let webViewManager = WebViewManager(configuration: webViewConfig)
        let testConfiguration = createTestConfiguration()
        
        defer {
            Task {
                await webViewManager.cleanup()
            }
        }
        
        // Test that distributed initialization works or fails gracefully
        do {
            try await webViewManager.initializeDistributed(with: testConfiguration)
            // If this succeeds, check that we can get empty platforms list
            let platforms = try await webViewManager.getConnectedPlatforms()
            #expect(platforms.isEmpty, "Should start with empty platforms list")
        } catch DistributedPlatformError.distributedClusterNotAvailable {
            withKnownIssue("DistributedCluster framework not available") {
                // Skip this test
            }
        } catch {
            Issue.record("Unexpected error in WebView distributed initialization: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    #if canImport(DistributedCluster)
    @Test("Platform registration performance with multiple platforms", 
          .timeLimit(.minutes(2)),
          .tags(.performance, .slow),
          arguments: [10, 50])
    @available(macOS 14.0, *)
    func platformRegistrationPerformance(platformCount: Int) async throws {
        let testConfiguration = createTestConfiguration()
        let distributedManager = DistributedPlatformManager(configuration: testConfiguration)
        
        defer {
            Task {
                await distributedManager.shutdown()
            }
        }
        
        do {
            try await distributedManager.initializeCluster()
            guard let coordinator = try await distributedManager.createCoordinator() else {
                withKnownIssue("Could not create coordinator") {}
                return
            }
            
            // Measure performance of registering multiple platforms
            let startTime = ContinuousClock.now
            
            for i in 0..<platformCount {
                let platformInfo = PlatformInfo(
                    id: "platform-\(i)",
                    deviceName: "Device \(i)",
                    platform: "macOS",
                    version: "14.0",
                    capabilities: ["test"]
                )
                
                try await coordinator.registerPlatform(platformInfo)
            }
            
            let elapsed = ContinuousClock.now - startTime
            print("Platform registration (\(platformCount) platforms) took: \(elapsed)")
            
            // Verify all platforms were registered
            let platforms = try await coordinator.getConnectedPlatforms()
            #expect(platforms.count == platformCount)
            
        } catch DistributedPlatformError.distributedClusterNotAvailable {
            withKnownIssue("DistributedCluster framework not available") {
                // Skip this test
            }
        }
    }
    
    @Test("Data sharing performance with different data sizes", 
          .timeLimit(.minutes(1)),
          .tags(.performance, .slow),
          arguments: [1024, 4096]) // 1KB, 4KB
    @available(macOS 14.0, *)
    func dataSharingPerformance(dataSize: Int) async throws {
        let testConfiguration = createTestConfiguration()
        let distributedManager = DistributedPlatformManager(configuration: testConfiguration)
        
        defer {
            Task {
                await distributedManager.shutdown()
            }
        }
        
        do {
            try await distributedManager.initializeCluster()
            guard let coordinator = try await distributedManager.createCoordinator() else {
                withKnownIssue("Could not create coordinator") {}
                return
            }
            
            let testData = Data(repeating: 0x42, count: dataSize)
            let operationCount = 25
            
            let startTime = ContinuousClock.now
            
            for i in 0..<operationCount {
                try await coordinator.shareData(key: "test-key-\(i)", value: testData)
            }
            
            let elapsed = ContinuousClock.now - startTime
            print("Data sharing (\(dataSize) bytes × \(operationCount) operations) took: \(elapsed)")
            
            // Verify data can be retrieved
            let retrievedData = try await coordinator.retrieveData(key: "test-key-0")
            #expect(retrievedData == testData)
            
        } catch DistributedPlatformError.distributedClusterNotAvailable {
            withKnownIssue("DistributedCluster framework not available") {
                // Skip this test
            }
        }
    }
    #endif
}

// MARK: - Test Tags

extension Tag {
    @Tag static var distributed: Self
    @Tag static var integration: Self
    @Tag static var performance: Self
    @Tag static var slow: Self
} 
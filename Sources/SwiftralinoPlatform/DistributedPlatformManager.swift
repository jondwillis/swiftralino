import Foundation
import SwiftralinoCore

#if canImport(Distributed)
import Distributed
#endif

#if canImport(DistributedCluster)
import DistributedCluster
import ServiceDiscovery
import NIOSSL
#endif

/// Manages distributed capabilities across SwiftralinoPlatform instances
/// Enables multi-device/multi-process coordination and communication
@available(macOS 14.0, iOS 16.0, *)
public class DistributedPlatformManager {
    
    // MARK: - Properties
    
    private var clusterSystem: ClusterSystem?
    public let configuration: DistributedConfiguration
    
    // MARK: - Initialization
    
    public init(configuration: DistributedConfiguration) {
        self.configuration = configuration
    }
    
    // MARK: - Cluster Management
    
    /// Initialize the distributed cluster system
    public func initializeCluster() async throws {
        #if canImport(DistributedCluster)
        clusterSystem = await ClusterSystem(configuration.clusterName) { settings in
            // Configure basic cluster settings
            settings.bindHost = configuration.host
            settings.bindPort = configuration.port
            
            // Configure discovery if needed
            if configuration.discovery != nil {
                // settings.discovery = discoveryConfiguration
            }
            
            // Configure security/TLS if needed
            if configuration.tls != nil {
                // settings.tls = tlsConfiguration
            }
        }
        
        print("🌐 Distributed cluster initialized: \(configuration.clusterName)")
        #else
        throw DistributedPlatformError.distributedClusterNotAvailable
        #endif
    }
    
    /// Join an existing cluster
    public func joinCluster(endpoint: Cluster.Endpoint) async throws {
        guard let clusterSystem = clusterSystem else {
            throw DistributedPlatformError.clusterNotInitialized
        }
        
        #if canImport(DistributedCluster)
        clusterSystem.cluster.join(endpoint: endpoint)
        print("🤝 Joined cluster at \(endpoint)")
        #endif
    }
    
    /// Create a distributed platform coordinator
    public func createCoordinator() async throws -> DistributedPlatformCoordinator? {
        guard let clusterSystem = clusterSystem else {
            throw DistributedPlatformError.clusterNotInitialized
        }
        
        #if canImport(DistributedCluster)
        let coordinator = DistributedPlatformCoordinator(actorSystem: clusterSystem)
        
        // Register coordinator with receptionist for discovery
        await clusterSystem.receptionist.checkIn(coordinator, with: DistributedReception.Key<DistributedPlatformCoordinator>.platformCoordinators)
        
        return coordinator
        #else
        return nil
        #endif
    }
    
    /// Find remote platform coordinators
    public func findCoordinators() async -> AsyncStream<DistributedPlatformCoordinator>? {
        guard let clusterSystem = clusterSystem else {
            return nil
        }
        
        #if canImport(DistributedCluster)
        let listing = await clusterSystem.receptionist.listing(of: DistributedPlatformCoordinator.self)
        return AsyncStream { continuation in
            Task {
                for await coordinator in listing {
                    continuation.yield(coordinator)
                }
                continuation.finish()
            }
        }
        #else
        return nil
        #endif
    }
    
    /// Shutdown the cluster
    public func shutdown() async {
        try? clusterSystem?.shutdown()
        clusterSystem = nil
        print("🛑 Distributed cluster shutdown")
    }
}

// MARK: - Distributed Platform Coordinator

#if canImport(DistributedCluster)
/// Distributed actor that coordinates SwiftralinoPlatform instances across devices/processes
@available(macOS 14.0, iOS 16.0, *)
public distributed actor DistributedPlatformCoordinator {
    
    public typealias ActorSystem = ClusterSystem
    
    private var connectedPlatforms: Set<PlatformInfo> = []
    private var sharedState: [String: Any] = [:]
    
    public init(actorSystem: ActorSystem) {
        self.actorSystem = actorSystem
    }
    
    /// Register a platform instance
    public distributed func registerPlatform(_ info: PlatformInfo) async throws {
        connectedPlatforms.insert(info)
        print("📱 Platform registered: \(info.deviceName) (\(info.platform))")
        
        // Notify other coordinators about new platform
        await broadcastPlatformUpdate(.joined(info))
    }
    
    /// Unregister a platform instance
    public distributed func unregisterPlatform(_ platformId: String) async throws {
        if let info = connectedPlatforms.first(where: { $0.id == platformId }) {
            connectedPlatforms.remove(info)
            print("📱 Platform unregistered: \(info.deviceName)")
            
            await broadcastPlatformUpdate(.left(info))
        }
    }
    
    /// Get list of connected platforms
    public distributed func getConnectedPlatforms() async -> [PlatformInfo] {
        return Array(connectedPlatforms)
    }
    
    /// Execute command across all platforms
    public distributed func executeAcrossPlatforms(_ command: DistributedCommand) async throws -> [CommandResult] {
        print("🚀 Executing command across \(connectedPlatforms.count) platforms: \(command.type)")
        
        var results: [CommandResult] = []
        
        // This would coordinate with WebViewManagers on each platform
        for platform in connectedPlatforms {
            let result = CommandResult(
                platformId: platform.id,
                success: true,
                output: "Command executed on \(platform.deviceName)",
                timestamp: Date()
            )
            results.append(result)
        }
        
        return results
    }
    
    /// Share data across platforms
    public distributed func shareData(key: String, value: Data) async throws {
        // Convert Data to serializable format for distributed storage
        sharedState[key] = value.base64EncodedString()
        print("📊 Data shared: \(key)")
    }
    
    /// Retrieve shared data
    public distributed func retrieveData(key: String) async throws -> Data? {
        guard let encodedString = sharedState[key] as? String else {
            return nil
        }
        return Data(base64Encoded: encodedString)
    }
    
    // Private helper methods
    private func broadcastPlatformUpdate(_ update: PlatformUpdate) async {
        // Implementation would notify other coordinators
        print("📢 Broadcasting platform update: \(update)")
    }
}
#endif

// MARK: - Supporting Types

public struct DistributedConfiguration {
    public let clusterName: String
    public let host: String
    public let port: Int
    public let discovery: ServiceDiscovery?
    public let tls: TLSConfiguration?
    
    public init(
        clusterName: String,
        host: String = "127.0.0.1",
        port: Int = 7337,
        discovery: ServiceDiscovery? = nil,
        tls: TLSConfiguration? = nil
    ) {
        self.clusterName = clusterName
        self.host = host
        self.port = port
        self.discovery = discovery
        self.tls = tls
    }
}

public struct PlatformInfo: Hashable, Codable {
    public let id: String
    public let deviceName: String
    public let platform: String
    public let version: String
    public let capabilities: [String]
    
    public init(id: String, deviceName: String, platform: String, version: String, capabilities: [String]) {
        self.id = id
        self.deviceName = deviceName
        self.platform = platform
        self.version = version
        self.capabilities = capabilities
    }
}

public struct DistributedCommand: Codable {
    public let id: String
    public let type: String
    public let payload: [String: String]
    public let timestamp: Date
    
    public init(id: String, type: String, payload: [String: String]) {
        self.id = id
        self.type = type
        self.payload = payload
        self.timestamp = Date()
    }
}

public struct CommandResult: Codable {
    public let platformId: String
    public let success: Bool
    public let output: String
    public let timestamp: Date
}

public enum PlatformUpdate {
    case joined(PlatformInfo)
    case left(PlatformInfo)
}

#if canImport(DistributedCluster)
extension DistributedReception.Key {
    static var platformCoordinators: DistributedReception.Key<DistributedPlatformCoordinator> { 
        DistributedReception.Key("platform-coordinators")
    }
}
#endif

// MARK: - Errors

public enum DistributedPlatformError: Error, LocalizedError {
    case distributedClusterNotAvailable
    case clusterNotInitialized
    case coordinatorNotFound
    case commandExecutionFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .distributedClusterNotAvailable:
            return "DistributedCluster framework not available"
        case .clusterNotInitialized:
            return "Cluster system not initialized"
        case .coordinatorNotFound:
            return "No distributed coordinator found"
        case .commandExecutionFailed(let message):
            return "Command execution failed: \(message)"
        }
    }
} 
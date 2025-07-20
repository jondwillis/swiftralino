import Foundation
import SwiftralinoCore

/// Protocol for implementing Swiftralino plugins
/// Inspired by Tauri's plugin system with Swift-specific enhancements
public protocol SwiftralinoPlugin {
    /// Unique identifier for the plugin
    static var identifier: String { get }
    
    /// Plugin display name
    static var name: String { get }
    
    /// Plugin version
    static var version: String { get }
    
    /// Plugin description
    static var description: String { get }
    
    /// Required permissions for this plugin
    static var requiredPermissions: [PluginPermission] { get }
    
    /// Initialize the plugin with configuration
    init(configuration: PluginConfiguration) throws
    
    /// Register the plugin's API endpoints
    func registerAPIs() -> [String: SwiftralinoAPI]
    
    /// Plugin lifecycle hooks
    func didLoad() async throws
    func willUnload() async throws
}

/// Plugin permissions system
public enum PluginPermission: String, CaseIterable, Codable {
    case filesystem = "filesystem"
    case network = "network"
    case process = "process"
    case system = "system"
    case clipboard = "clipboard"
    case notifications = "notifications"
    case camera = "camera"
    case microphone = "microphone"
    case location = "location"
    case keychain = "keychain"
    case printjobs = "printjobs"
    
    public var description: String {
        switch self {
        case .filesystem: return "Access to file system operations"
        case .network: return "Network and HTTP requests"
        case .process: return "Process management and execution"
        case .system: return "System information and configuration"
        case .clipboard: return "Clipboard read/write access"
        case .notifications: return "Display system notifications"
        case .camera: return "Camera access for photos/video"
        case .microphone: return "Microphone access for recording"
        case .location: return "Location services"
        case .keychain: return "Secure credential storage"
        case .printjobs: return "Printing capabilities"
        }
    }
}

/// Plugin configuration passed during initialization
public struct PluginConfiguration: Codable {
    public let pluginId: String
    public let settings: [String: AnyCodable]
    public let dataDirectory: String
    public let isDebugMode: Bool
    
    public init(pluginId: String, settings: [String: AnyCodable] = [:], dataDirectory: String, isDebugMode: Bool = false) {
        self.pluginId = pluginId
        self.settings = settings
        self.dataDirectory = dataDirectory
        self.isDebugMode = isDebugMode
    }
}

/// Plugin manager for loading and managing plugins
@available(macOS 12.0, *)
public actor PluginRegistry {
    
    private var loadedPlugins: [String: SwiftralinoPlugin] = [:]
    private var pluginAPIs: [String: SwiftralinoAPI] = [:]
    private let configuration: SwiftralinoConfig
    private let pluginDirectory: String
    
    public init(configuration: SwiftralinoConfig, pluginDirectory: String = ".swiftralino/plugins") {
        self.configuration = configuration
        self.pluginDirectory = pluginDirectory
    }
    
    /// Load all configured plugins
    public func loadPlugins() async throws {
        print("📦 Loading Swiftralino plugins...")
        
        // Load built-in plugins
        try await loadBuiltinPlugins()
        
        // Load external plugins
        for pluginId in configuration.plugins {
            try await loadPlugin(identifier: pluginId)
        }
        
        print("✅ Loaded \(loadedPlugins.count) plugins")
    }
    
    /// Load a specific plugin by identifier
    public func loadPlugin(identifier: String) async throws {
        guard loadedPlugins[identifier] == nil else {
            print("ℹ️ Plugin \(identifier) already loaded")
            return
        }
        
        // For now, we'll implement a basic plugin loading mechanism
        // In a full implementation, this would dynamically load plugin bundles
        print("📦 Loading plugin: \(identifier)")
        
        // This is where we'd implement dynamic loading of plugin bundles
        // For now, we'll register some example plugins
        if let plugin = createBuiltinPlugin(identifier: identifier) {
            let config = PluginConfiguration(
                pluginId: identifier,
                dataDirectory: "\(pluginDirectory)/\(identifier)"
            )
            
            let pluginInstance = try plugin.init(configuration: config)
            loadedPlugins[identifier] = pluginInstance
            
            // Register plugin's APIs
            let apis = pluginInstance.registerAPIs()
            for (apiName, api) in apis {
                pluginAPIs[apiName] = api
                print("🔌 Registered API: \(apiName) from plugin \(identifier)")
            }
            
            // Call plugin lifecycle hook
            try await pluginInstance.didLoad()
            print("✅ Loaded plugin: \(identifier)")
        } else {
            throw PluginError.pluginNotFound(identifier)
        }
    }
    
    /// Unload a plugin
    public func unloadPlugin(identifier: String) async throws {
        guard let plugin = loadedPlugins[identifier] else {
            throw PluginError.pluginNotFound(identifier)
        }
        
        // Call plugin lifecycle hook
        try await plugin.willUnload()
        
        // Remove plugin's APIs
        let apis = plugin.registerAPIs()
        for (apiName, _) in apis {
            pluginAPIs.removeValue(forKey: apiName)
        }
        
        loadedPlugins.removeValue(forKey: identifier)
        print("🗑️ Unloaded plugin: \(identifier)")
    }
    
    /// Get API by name from loaded plugins
    public func getAPI(name: String) -> SwiftralinoAPI? {
        return pluginAPIs[name]
    }
    
    /// List all loaded plugins
    public func getLoadedPlugins() -> [String] {
        return Array(loadedPlugins.keys)
    }
    
    /// Load built-in plugins
    private func loadBuiltinPlugins() async throws {
        let builtinPlugins = [
            "notification",
            "clipboard",
            "dialog",
            "shell",
            "updater"
        ]
        
        for pluginId in builtinPlugins {
            try await loadPlugin(identifier: pluginId)
        }
    }
    
    /// Create built-in plugin instances
    private func createBuiltinPlugin(identifier: String) -> SwiftralinoPlugin.Type? {
        switch identifier {
        case "notification":
            return NotificationPlugin.self
        case "clipboard":
            return ClipboardPlugin.self
        case "dialog":
            return DialogPlugin.self
        case "shell":
            return ShellPlugin.self
        case "updater":
            return UpdaterPlugin.self
        default:
            return nil
        }
    }
}

// MARK: - Built-in Plugins

/// Notification plugin for system notifications
public struct NotificationPlugin: SwiftralinoPlugin {
    public static let identifier = "notification"
    public static let name = "Notification Plugin"
    public static let version = "1.0.0"
    public static let description = "Display system notifications"
    public static let requiredPermissions: [PluginPermission] = [.notifications]
    
    private let configuration: PluginConfiguration
    
    public init(configuration: PluginConfiguration) throws {
        self.configuration = configuration
    }
    
    public func registerAPIs() -> [String: SwiftralinoAPI] {
        return ["notification": NotificationAPI()]
    }
    
    public func didLoad() async throws {
        print("🔔 Notification plugin loaded")
    }
    
    public func willUnload() async throws {
        print("🔔 Notification plugin unloading")
    }
}

/// Clipboard plugin for clipboard operations
public struct ClipboardPlugin: SwiftralinoPlugin {
    public static let identifier = "clipboard"
    public static let name = "Clipboard Plugin" 
    public static let version = "1.0.0"
    public static let description = "Clipboard read/write operations"
    public static let requiredPermissions: [PluginPermission] = [.clipboard]
    
    private let configuration: PluginConfiguration
    
    public init(configuration: PluginConfiguration) throws {
        self.configuration = configuration
    }
    
    public func registerAPIs() -> [String: SwiftralinoAPI] {
        return ["clipboard": ClipboardAPI()]
    }
    
    public func didLoad() async throws {
        print("📋 Clipboard plugin loaded")
    }
    
    public func willUnload() async throws {
        print("📋 Clipboard plugin unloading")
    }
}

/// Dialog plugin for native dialogs
public struct DialogPlugin: SwiftralinoPlugin {
    public static let identifier = "dialog"
    public static let name = "Dialog Plugin"
    public static let version = "1.0.0" 
    public static let description = "Native system dialogs"
    public static let requiredPermissions: [PluginPermission] = []
    
    private let configuration: PluginConfiguration
    
    public init(configuration: PluginConfiguration) throws {
        self.configuration = configuration
    }
    
    public func registerAPIs() -> [String: SwiftralinoAPI] {
        return ["dialog": DialogAPI()]
    }
    
    public func didLoad() async throws {
        print("💬 Dialog plugin loaded")
    }
    
    public func willUnload() async throws {
        print("💬 Dialog plugin unloading")
    }
}

/// Shell plugin for shell command execution
public struct ShellPlugin: SwiftralinoPlugin {
    public static let identifier = "shell"
    public static let name = "Shell Plugin"
    public static let version = "1.0.0"
    public static let description = "Execute shell commands"
    public static let requiredPermissions: [PluginPermission] = [.process]
    
    private let configuration: PluginConfiguration
    
    public init(configuration: PluginConfiguration) throws {
        self.configuration = configuration
    }
    
    public func registerAPIs() -> [String: SwiftralinoAPI] {
        return ["shell": ShellAPI()]
    }
    
    public func didLoad() async throws {
        print("🐚 Shell plugin loaded")
    }
    
    public func willUnload() async throws {
        print("🐚 Shell plugin unloading")
    }
}

/// Updater plugin for app updates
public struct UpdaterPlugin: SwiftralinoPlugin {
    public static let identifier = "updater"
    public static let name = "Updater Plugin"
    public static let version = "1.0.0"
    public static let description = "Application auto-updater"
    public static let requiredPermissions: [PluginPermission] = [.network, .filesystem]
    
    private let configuration: PluginConfiguration
    
    public init(configuration: PluginConfiguration) throws {
        self.configuration = configuration
    }
    
    public func registerAPIs() -> [String: SwiftralinoAPI] {
        return ["updater": UpdaterAPI()]
    }
    
    public func didLoad() async throws {
        print("🔄 Updater plugin loaded")
    }
    
    public func willUnload() async throws {
        print("🔄 Updater plugin unloading")
    }
}

// MARK: - Plugin Errors

public enum PluginError: Error, LocalizedError {
    case pluginNotFound(String)
    case permissionDenied(PluginPermission)
    case initializationFailed(String)
    case apiRegistrationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .pluginNotFound(let identifier):
            return "Plugin not found: \(identifier)"
        case .permissionDenied(let permission):
            return "Permission denied: \(permission.rawValue)"
        case .initializationFailed(let message):
            return "Plugin initialization failed: \(message)"
        case .apiRegistrationFailed(let message):
            return "API registration failed: \(message)"
        }
    }
} 
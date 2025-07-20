import Foundation

/// Simplified configuration for plugin system
/// This avoids circular dependency while providing necessary types
public struct SwiftralinoConfig: Codable {
    public let plugins: [String]
    
    public init(plugins: [String] = []) {
        self.plugins = plugins
    }
    
    public static func load(from path: String = "swiftralino.json") throws -> SwiftralinoConfig {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(SwiftralinoConfig.self, from: data)
    }
} 
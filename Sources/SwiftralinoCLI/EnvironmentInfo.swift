import Foundation
#if canImport(Darwin)
import Darwin
#endif

public struct EnvironmentInfo {
    public init() {}
    
    public func display() {
        print("\n🔍 Swiftralino Environment Information")
        print("=====================================\n")
        
        displaySwiftInfo()
        displaySystemInfo()
        displayProjectInfo()
        displayDependencies()
    }
    
    private func displaySwiftInfo() {
        print("📦 Swift")
        print("  - Version: \(getSwiftVersion())")
        print("  - Platform: \(getSwiftPlatform())")
        print("  - Architecture: \(getArchitecture())")
        print("")
    }
    
    private func displaySystemInfo() {
        print("💻 System")
        print("  - OS: \(getOperatingSystem())")
        print("  - Version: \(getOperatingSystemVersion())")
        print("  - Kernel: \(getKernelVersion())")
        print("  - Memory: \(getMemoryInfo())")
        print("")
    }
    
    private func displayProjectInfo() {
        print("🚀 Project")
        
        // Check if we're in a Swiftralino project
        let configExists = FileManager.default.fileExists(atPath: "swiftralino.json")
        if configExists {
            if let config = try? SwiftralinoConfig.load() {
                print("  - Name: \(config.app.productName)")
                print("  - Version: \(config.app.version)")
                print("  - Identifier: \(config.app.identifier)")
                if let category = config.app.category {
                    print("  - Category: \(category.rawValue)")
                }
                print("  - Plugins: \(config.plugins.count)")
            }
        } else {
            print("  - No Swiftralino project found in current directory")
            print("  - Run 'swiftralino create <project-name>' to create a new project")
        }
        print("")
    }
    
    private func displayDependencies() {
        print("📚 Dependencies")
        
        // Check for common tools
        let tools = [
            ("Node.js", "node --version"),
            ("npm", "npm --version"),
            ("Bun", "bun --version"),
            ("Deno", "deno --version"),
            ("Git", "git --version"),
            ("Xcode", "xcodebuild -version")
        ]
        
        for (name, command) in tools {
            let version = getToolVersion(command: command)
            let status = version.isEmpty ? "❌ Not found" : "✅ \(version)"
            print("  - \(name): \(status)")
        }
        print("")
    }
    
    // MARK: - Helper Methods
    
    private func getSwiftVersion() -> String {
        return getCommandOutput("swift --version") ?? "Unknown"
    }
    
    private func getSwiftPlatform() -> String {
        #if os(macOS)
        return "macOS"
        #elseif os(Linux)
        return "Linux"
        #elseif os(Windows)
        return "Windows"
        #else
        return "Unknown"
        #endif
    }
    
    private func getArchitecture() -> String {
        #if arch(x86_64)
        return "x86_64"
        #elseif arch(arm64)
        return "arm64"
        #elseif arch(i386)
        return "i386"
        #else
        return "Unknown"
        #endif
    }
    
    private func getOperatingSystem() -> String {
        #if os(macOS)
        return "macOS"
        #elseif os(Linux)
        if let distro = getLinuxDistribution() {
            return distro
        }
        return "Linux"
        #elseif os(Windows)
        return "Windows"
        #else
        return "Unknown"
        #endif
    }
    
    private func getOperatingSystemVersion() -> String {
        let processInfo = ProcessInfo.processInfo
        let version = processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
    
    private func getKernelVersion() -> String {
        #if canImport(Darwin)
        var systemInfo = utsname()
        uname(&systemInfo)
        let release = withUnsafePointer(to: &systemInfo.release) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        return release
        #else
        return getCommandOutput("uname -r") ?? "Unknown"
        #endif
    }
    
    private func getMemoryInfo() -> String {
        #if os(macOS)
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let gb = Double(totalMemory) / 1_073_741_824 // Convert to GB
        return String(format: "%.1f GB", gb)
        #else
        return "Unknown"
        #endif
    }
    
    private func getLinuxDistribution() -> String? {
        // Try to read /etc/os-release
        if let osRelease = try? String(contentsOfFile: "/etc/os-release") {
            let lines = osRelease.components(separatedBy: .newlines)
            for line in lines {
                if line.hasPrefix("PRETTY_NAME=") {
                    let name = line.replacingOccurrences(of: "PRETTY_NAME=", with: "")
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    return name
                }
            }
        }
        return nil
    }
    
    private func getToolVersion(command: String) -> String {
        let output = getCommandOutput(command) ?? ""
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func getCommandOutput(_ command: String) -> String? {
        let task = Process()
        let pipe = Pipe()
        
        // Split command into executable and arguments
        let components = command.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let executable = components.first else { return nil }
        
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = [String(executable)] + (components.count > 1 ? [String(components[1])] : [])
        task.standardOutput = pipe
        task.standardError = Pipe() // Suppress error output
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
} 
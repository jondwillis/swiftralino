import Foundation
import SwiftralinoCore

// Global state for signal handling (required for C function pointers)
var globalSwiftralinoApp: SwiftralinoApp?
var globalIsShuttingDown = false

/// Headless Swiftralino server for Docker/cloud deployment
/// Runs only the WebSocket server without any WebView or GUI components
@main
struct SwiftralinoHeadless {
    static func main() async {
        print("🐳 Starting Swiftralino Headless Server")
        print("=====================================")
        
        // Configure server from environment variables or defaults
        let host = ProcessInfo.processInfo.environment["SWIFTRALINO_HOST"] ?? "0.0.0.0"
        let port = Int(ProcessInfo.processInfo.environment["SWIFTRALINO_PORT"] ?? "8080") ?? 8080
        
        // TLS is enabled by default for security - only disable when explicitly opted out
        let tlsOptOut = ProcessInfo.processInfo.environment["SWIFTRALINO_DISABLE_TLS"]?.lowercased() == "true"
        let enableTLS = !tlsOptOut
        
        // Check for certificate configuration
        let (hasCerts, certInfo) = await checkCertificateConfiguration()
        
        if enableTLS && !hasCerts {
            await promptForCertificateSetup()
            print("\n❌ TLS is enabled but no certificates found.")
            print("   Set SWIFTRALINO_DISABLE_TLS=true to run without TLS (not recommended for production)")
            exit(1)
        }
        
        if !enableTLS {
            print("⚠️  TLS is DISABLED - this is not recommended for production use!")
            print("   Consider setting up certificates for secure deployment.")
        }
        
        let serverConfig = ServerConfiguration(
            host: host,
            port: port,
            enableTLS: enableTLS
        )
        
        let webViewConfig = WebViewConfiguration(
            initialURL: "\(enableTLS ? "https" : "http")://\(host == "0.0.0.0" ? "localhost" : host):\(port)",
            windowTitle: "Swiftralino Headless",
            windowWidth: 1200,
            windowHeight: 800,
            enableDeveloperTools: false
        )
        
        let appConfig = AppConfiguration(
            server: serverConfig,
            webView: webViewConfig
        )
        
        // Create Swiftralino app without WebView manager (headless mode)
        let swiftralinoApp = SwiftralinoApp(configuration: appConfig, webViewManager: nil)
        globalSwiftralinoApp = swiftralinoApp
        
        // Set up signal handling for graceful shutdown
        let shutdownHandler: @convention(c) (Int32) -> Void = { signal in
            guard !globalIsShuttingDown else { return }
            globalIsShuttingDown = true
            
            print("\n🛑 Received shutdown signal (\(signal))")
            print("🔄 Shutting down gracefully...")
            
            Task {
                await globalSwiftralinoApp?.shutdown()
                print("✅ Headless server shutdown complete")
                exit(0)
            }
        }
        
        signal(SIGINT, shutdownHandler)
        signal(SIGTERM, shutdownHandler)
        
        do {
            // Launch the headless server
            try await swiftralinoApp.launch()
            
            let scheme = enableTLS ? "https" : "http"
            let wsScheme = enableTLS ? "wss" : "ws"
            
            print("\n✅ Headless server running on \(scheme)://\(host):\(port)")
            print("   📡 WebSocket bridge: \(wsScheme)://\(host):\(port)/bridge")
            print("   🌐 Web interface: \(scheme)://\(host):\(port)")
            print("   🔒 TLS: \(enableTLS ? "Enabled" : "Disabled")")
            if enableTLS && !certInfo.isEmpty {
                print("   🔐 Certificate: \(certInfo)")
            }
            print("   🐳 Docker ready - Press Ctrl+C to stop")
            
            // Keep running indefinitely
            while !globalIsShuttingDown {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
            
        } catch {
            print("❌ Failed to start headless server: \(error)")
            exit(1)
        }
    }
    
    // MARK: - Certificate Management
    
    /// Check for existing certificates and their configuration
    static func checkCertificateConfiguration() async -> (Bool, String) {
        let certPaths = [
            "/app/ssl/cert.pem",
            "/app/ssl/server.crt", 
            "/etc/letsencrypt/live/\(ProcessInfo.processInfo.environment["DOMAIN"] ?? "localhost")/cert.pem",
            "/usr/local/share/ca-certificates/swiftralino.crt"
        ]
        
        for certPath in certPaths {
            if FileManager.default.fileExists(atPath: certPath) {
                if let certInfo = getCertificateInfo(certPath) {
                    return (true, certInfo)
                }
            }
        }
        
        return (false, "")
    }
    
    /// Get certificate information for display
    static func getCertificateInfo(_ path: String) -> String? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        process.arguments = ["x509", "-in", path, "-noout", "-subject", "-dates"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let _ = String(data: data, encoding: .utf8) ?? ""
            
            if process.terminationStatus == 0 {
                return "\(URL(fileURLWithPath: path).lastPathComponent) (\(path))"
            }
        } catch {
            // OpenSSL not available or certificate invalid
        }
        
        return "Certificate found at \(path)"
    }
    
    /// Prompt user for certificate setup options
    static func promptForCertificateSetup() async {
        print("\n🔒 TLS Certificate Setup Required")
        print("================================")
        print("")
        print("Swiftralino requires TLS certificates for secure operation.")
        print("Choose one of the following options:")
        print("")
        print("1. 🌐 Let's Encrypt (Recommended for production)")
        print("   docker-compose run --rm certbot")
        print("")
        print("2. 🔑 Self-signed certificate (Development/internal use)")
        print("   make generate-cert")
        print("")
        print("3. 📁 Provide your own certificate")
        print("   Place cert.pem and key.pem in ./ssl/ directory")
        print("")
        print("4. ⚠️  Disable TLS (Not recommended)")
        print("   Set SWIFTRALINO_DISABLE_TLS=true")
        print("")
    }
} 
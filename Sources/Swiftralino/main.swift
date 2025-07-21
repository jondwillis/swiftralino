import Foundation
import SwiftralinoCore
import SwiftralinoPlatform

#if canImport(Cocoa)
import Cocoa
#endif

@main
struct SwiftralinoDemo {
    static func main() {
        print("🚀 Starting Swiftralino Demo Application")
        print("===========================================")
        
        #if canImport(Cocoa)
        // Set up NSApplication for proper GUI event handling
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        
        let delegate = SwiftralinoAppDelegate()
        app.delegate = delegate
        
        // Configure the Swiftralino application
        let serverConfig = ServerConfiguration(
            host: "127.0.0.1",
            port: 8080
            // TLS enabled by default
        )
        
        let webViewConfig = WebViewConfiguration(
            initialURL: "https://127.0.0.1:8080", // HTTPS by default
            windowTitle: "Swiftralino Demo",
            windowWidth: 1200,
            windowHeight: 800,
            enableDeveloperTools: true
        )
        
        let appConfig = AppConfiguration(
            server: serverConfig,
            webView: webViewConfig
        )
        
        // Create WebView manager and Swiftralino application
        let webViewManager = WebViewManager(configuration: webViewConfig)
        let swiftralinoApp = SwiftralinoApp(configuration: appConfig, webViewManager: webViewManager)
        delegate.swiftralinoApp = swiftralinoApp
        
        // Simple, direct signal handling for development
        #if DEBUG
        signal(SIGINT) { _ in
            print("\n🛑 Received shutdown signal")
            print("🔄 Development mode: exiting immediately...")
            exit(0)
        }
        signal(SIGTERM) { _ in
            print("\n🛑 Received shutdown signal")
            print("🔄 Development mode: exiting immediately...")
            exit(0)
        }
        #else
        // Production signal handling with proper cleanup
        var signalSourceInt: DispatchSourceSignal?
        var signalSourceTerm: DispatchSourceSignal?
        var isShuttingDown = false
        
        let shutdownHandler = {
            guard !isShuttingDown else { return }
            isShuttingDown = true
            
            print("\n🛑 Received shutdown signal")
            
            // Cancel signal sources
            signalSourceInt?.cancel()
            signalSourceTerm?.cancel()
            
            Task {
                await swiftralinoApp.shutdown()
                DispatchQueue.main.async {
                    NSApp.terminate(nil)
                }
            }
        }
        
        signalSourceInt = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        signalSourceTerm = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        
        signalSourceInt?.setEventHandler(handler: shutdownHandler)
        signalSourceTerm?.setEventHandler(handler: shutdownHandler)
        
        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)
        signalSourceInt?.resume()
        signalSourceTerm?.resume()
        #endif
        
        // Launch the Swiftralino application in background
        Task {
            do {
                try await swiftralinoApp.launch()
                
                print("\n✅ Application running. Press Ctrl+C to quit.")
                print("   Open your browser to: https://127.0.0.1:8080")
                print("   WebSocket bridge available at: wss://127.0.0.1:8080/bridge")
                
                // Check certificates and show appropriate guidance
                let (hasCerts, certInfo) = await checkCertificateConfiguration()
                if !hasCerts {
                    await promptForCertificateSetup()
                } else if !certInfo.isEmpty {
                    print("   🔐 Certificate: \(certInfo)")
                }
                
            } catch {
                print("❌ Failed to start application: \(error)")
                exit(1)
            }
        }
        
        // Run the NSApplication main loop for proper GUI event handling
        app.run()
        
        #else
        // Non-macOS platforms - use async main
        Task {
            await runAsync()
        }
        RunLoop.main.run()
        #endif
    }
    
    #if !canImport(Cocoa)
    static func runAsync() async {
        // Configure the application
        let serverConfig = ServerConfiguration(
            host: "127.0.0.1",
            port: 8080
            // TLS enabled by default
        )
        
        let webViewConfig = WebViewConfiguration(
            initialURL: "https://127.0.0.1:8080", // HTTPS by default
            windowTitle: "Swiftralino Demo",
            windowWidth: 1200,
            windowHeight: 800,
            enableDeveloperTools: true
        )
        
        let appConfig = AppConfiguration(
            server: serverConfig,
            webView: webViewConfig
        )
        
        // Create and launch the application
        let app = SwiftralinoApp(configuration: appConfig)
        
        do {
            // Launch the application
            try await app.launch()
            
            print("\n✅ Application running. Press Ctrl+C to quit.")
            print("   Open your browser to: https://127.0.0.1:8080")
            print("   WebSocket bridge available at: wss://127.0.0.1:8080/bridge")
            
            // Check certificates and show appropriate guidance
            let (hasCerts, certInfo) = await checkCertificateConfiguration()
            if !hasCerts {
                await promptForCertificateSetup()
            } else if !certInfo.isEmpty {
                print("   🔐 Certificate: \(certInfo)")
            }
            
            // Keep running indefinitely
            while true {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
            
        } catch {
            print("❌ Failed to start application: \(error)")
            Foundation.exit(1)
        }
    }
    #endif
    
    // MARK: - Certificate Management
    
    /// Check for existing certificates and their configuration
    static func checkCertificateConfiguration() async -> (Bool, String) {
        let certPaths = [
            "./ssl/cert.pem",
            "./ssl/server.crt",
            "/usr/local/share/ca-certificates/swiftralino.crt",
            // User's home directory
            "\(NSHomeDirectory())/ssl/cert.pem",
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
        print("\n💡 TLS Certificate Setup:")
        print("   Run `make generate-cert` to create development certificates")
        print("   Then `make trust-cert-macos` to eliminate browser warnings")
        print("")
        print("   Or disable TLS in ServerConfiguration (not recommended)")
    }
} 
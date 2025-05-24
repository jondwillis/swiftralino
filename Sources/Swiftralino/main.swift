import Foundation
import SwiftralinoCore

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
            port: 8080,
            enableTLS: false
        )
        
        let webViewConfig = WebViewConfiguration(
            initialURL: "http://127.0.0.1:8080",
            windowTitle: "Swiftralino Demo",
            windowWidth: 1200,
            windowHeight: 800,
            enableDeveloperTools: true
        )
        
        let appConfig = AppConfiguration(
            server: serverConfig,
            webView: webViewConfig
        )
        
        // Create and launch the Swiftralino application
        let swiftralinoApp = SwiftralinoApp(configuration: appConfig)
        delegate.swiftralinoApp = swiftralinoApp
        
        // Set up signal handling for graceful shutdown
        let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        signalSource.setEventHandler {
            print("\n🛑 Received shutdown signal")
            delegate.terminateApp()
        }
        signal(SIGINT, SIG_IGN)
        signalSource.resume()
        
        // Launch the Swiftralino application in background
        Task {
            do {
                try await swiftralinoApp.launch()
                
                print("\n✅ Application running. Press Ctrl+C to quit.")
                print("   Open your browser to: http://127.0.0.1:8080")
                print("   WebSocket bridge available at: ws://127.0.0.1:8080/bridge")
                
            } catch {
                print("❌ Failed to start application: \(error)")
                DispatchQueue.main.async {
                    NSApp.terminate(nil)
                }
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
            port: 8080,
            enableTLS: false
        )
        
        let webViewConfig = WebViewConfiguration(
            initialURL: "http://127.0.0.1:8080",
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
            print("   Open your browser to: http://127.0.0.1:8080")
            print("   WebSocket bridge available at: ws://127.0.0.1:8080/bridge")
            
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
} 
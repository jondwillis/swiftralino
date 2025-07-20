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
        
        // Create WebView manager and Swiftralino application
        let webViewManager = WebViewManager(configuration: webViewConfig)
        let swiftralinoApp = SwiftralinoApp(configuration: appConfig, webViewManager: webViewManager)
        delegate.swiftralinoApp = swiftralinoApp
        
        // Set up signal handling for graceful shutdown - improved version
        var signalSourceInt: DispatchSourceSignal?
        var signalSourceTerm: DispatchSourceSignal?
        var isShuttingDown = false
        var shutdownSemaphore = DispatchSemaphore(value: 0)
        
        let performShutdown = { @MainActor in
            guard !isShuttingDown else { return }
            isShuttingDown = true
            
            print("\n🛑 Received shutdown signal")
            
            // Cancel signal sources first to prevent race conditions
            signalSourceInt?.cancel()
            signalSourceTerm?.cancel()
            
            // Perform shutdown in a task that completes before termination
            Task {
                await swiftralinoApp.shutdown()
                
                // Signal that shutdown is complete
                shutdownSemaphore.signal()
            }
        }
        
        let shutdownHandler = {
            DispatchQueue.main.async {
                Task { @MainActor in
                    await performShutdown()
                }
            }
            
            // Wait for shutdown to complete before proceeding
            _ = shutdownSemaphore.wait(timeout: .now() + 5.0)
            
            // Use different termination strategies based on build type
            #if DEBUG
            print("🔄 Development mode: exiting cleanly...")
            // Give a moment for any final cleanup
            Thread.sleep(forTimeInterval: 0.1)
            Foundation.exit(0)
            #else
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
            #endif
        }
        
        signalSourceInt = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global(qos: .userInitiated))
        signalSourceTerm = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .global(qos: .userInitiated))
        
        signalSourceInt?.setEventHandler(handler: shutdownHandler)
        signalSourceTerm?.setEventHandler(handler: shutdownHandler)
        
        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)
        signalSourceInt?.resume()
        signalSourceTerm?.resume()
        
        // Launch the Swiftralino application in background
        Task {
            do {
                try await swiftralinoApp.launch()
                
                print("\n✅ Application running. Press Ctrl+C to quit.")
                print("   Open your browser to: http://127.0.0.1:8080")
                print("   WebSocket bridge available at: ws://127.0.0.1:8080/bridge")
                
            } catch {
                print("❌ Failed to start application: \(error)")
                
                // Clean up signal sources on error
                signalSourceInt?.cancel()
                signalSourceTerm?.cancel()
                
                await MainActor.run {
                    #if DEBUG
                    Foundation.exit(1)
                    #else
                    NSApp.terminate(nil)
                    #endif
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
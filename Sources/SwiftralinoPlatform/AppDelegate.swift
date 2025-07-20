#if canImport(Cocoa)
import Cocoa
import Foundation
import SwiftralinoCore

/// NSApplicationDelegate for proper macOS application lifecycle management
@available(macOS 12.0, *)
public class SwiftralinoAppDelegate: NSObject, NSApplicationDelegate {
    
    public var swiftralinoApp: SwiftralinoApp?
    private var shouldTerminate = false
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        print("🍎 NSApplication finished launching")
    }
    
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !shouldTerminate else {
            return .terminateNow
        }
        
        // Start async shutdown process
        shouldTerminate = true
        Task {
            await swiftralinoApp?.shutdown()
            DispatchQueue.main.async {
                NSApp.reply(toApplicationShouldTerminate: true)
            }
        }
        
        return .terminateLater
    }
    
    public func terminateApp() {
        DispatchQueue.main.async {
            NSApp.terminate(nil)
        }
    }
}
#endif 
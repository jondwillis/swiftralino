import Foundation
import SwiftralinoCore

#if canImport(UserNotifications)
import UserNotifications
#endif

#if canImport(AppKit)
import AppKit
#endif

// MARK: - Notification API

public struct NotificationAPI: SwiftralinoAPI {
    public let name = "notification"
    public let description = "Display system notifications"
    
    public func execute(parameters: [String: AnyCodable]?) async throws -> [String: Any] {
        guard let parameters = parameters,
              let operation = parameters["operation"]?.value as? String else {
            throw APIError.missingParameter("operation")
        }
        
        switch operation {
        case "show":
            guard let title = parameters["title"]?.value as? String else {
                throw APIError.missingParameter("title")
            }
            let body = parameters["body"]?.value as? String
            let icon = parameters["icon"]?.value as? String
            
            return try await showNotification(title: title, body: body, icon: icon)
            
        case "requestPermission":
            return try await requestNotificationPermission()
            
        default:
            throw APIError.unsupportedOperation(operation)
        }
    }
    
    private func showNotification(title: String, body: String?, icon: String?) async throws -> [String: Any] {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = title
        if let body = body {
            content.body = body
        }
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        try await center.add(request)
        return ["success": true]
        #else
        return ["success": false, "error": "Notifications not supported on this platform"]
        #endif
    }
    
    private func requestNotificationPermission() async throws -> [String: Any] {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        return ["granted": granted]
        #else
        return ["granted": false, "error": "Notifications not supported on this platform"]
        #endif
    }
}

// MARK: - Clipboard API

public struct ClipboardAPI: SwiftralinoAPI {
    public let name = "clipboard"
    public let description = "Clipboard read/write operations"
    
    public func execute(parameters: [String: AnyCodable]?) async throws -> [String: Any] {
        guard let parameters = parameters,
              let operation = parameters["operation"]?.value as? String else {
            throw APIError.missingParameter("operation")
        }
        
        switch operation {
        case "writeText":
            guard let text = parameters["text"]?.value as? String else {
                throw APIError.missingParameter("text")
            }
            return writeTextToClipboard(text)
            
        case "readText":
            return readTextFromClipboard()
            
        case "clear":
            return clearClipboard()
            
        default:
            throw APIError.unsupportedOperation(operation)
        }
    }
    
    private func writeTextToClipboard(_ text: String) -> [String: Any] {
        #if canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        return ["success": true]
        #else
        return ["success": false, "error": "Clipboard not supported on this platform"]
        #endif
    }
    
    private func readTextFromClipboard() -> [String: Any] {
        #if canImport(AppKit)
        let pasteboard = NSPasteboard.general
        if let text = pasteboard.string(forType: .string) {
            return ["text": text]
        } else {
            return ["text": NSNull()]
        }
        #else
        return ["text": NSNull(), "error": "Clipboard not supported on this platform"]
        #endif
    }
    
    private func clearClipboard() -> [String: Any] {
        #if canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return ["success": true]
        #else
        return ["success": false, "error": "Clipboard not supported on this platform"]
        #endif
    }
}

// MARK: - Dialog API

public struct DialogAPI: SwiftralinoAPI {
    public let name = "dialog"
    public let description = "Native system dialogs"
    
    public func execute(parameters: [String: AnyCodable]?) async throws -> [String: Any] {
        guard let parameters = parameters,
              let operation = parameters["operation"]?.value as? String else {
            throw APIError.missingParameter("operation")
        }
        
        switch operation {
        case "message":
            return try await showMessageDialog(parameters: parameters)
            
        case "confirm":
            return try await showConfirmDialog(parameters: parameters)
            
        case "open":
            return try await showOpenDialog(parameters: parameters)
            
        case "save":
            return try await showSaveDialog(parameters: parameters)
            
        default:
            throw APIError.unsupportedOperation(operation)
        }
    }
    
    private func showMessageDialog(parameters: [String: AnyCodable]) async throws -> [String: Any] {
        guard let message = parameters["message"]?.value as? String else {
            throw APIError.missingParameter("message")
        }
        
        let title = parameters["title"]?.value as? String ?? "Message"
        
        #if canImport(AppKit)
        return await MainActor.run {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return ["clicked": true]
        }
        #else
        print("Dialog: \(title) - \(message)")
        return ["clicked": true]
        #endif
    }
    
    private func showConfirmDialog(parameters: [String: AnyCodable]) async throws -> [String: Any] {
        guard let message = parameters["message"]?.value as? String else {
            throw APIError.missingParameter("message")
        }
        
        let title = parameters["title"]?.value as? String ?? "Confirm"
        
        #if canImport(AppKit)
        return await MainActor.run {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            return ["confirmed": response == .alertFirstButtonReturn]
        }
        #else
        print("Confirm: \(title) - \(message)")
        return ["confirmed": true]
        #endif
    }
    
    private func showOpenDialog(parameters: [String: AnyCodable]) async throws -> [String: Any] {
        #if canImport(AppKit)
        return await MainActor.run {
            let panel = NSOpenPanel()
            panel.title = parameters["title"]?.value as? String ?? "Open File"
            panel.canChooseFiles = parameters["files"]?.value as? Bool ?? true
            panel.canChooseDirectories = parameters["directories"]?.value as? Bool ?? false
            panel.allowsMultipleSelection = parameters["multiple"]?.value as? Bool ?? false
            
            let response = panel.runModal()
            if response == .OK {
                let paths = panel.urls.map { $0.path }
                return ["paths": paths]
            } else {
                return ["paths": []]
            }
        }
        #else
        return ["paths": [], "error": "File dialogs not supported on this platform"]
        #endif
    }
    
    private func showSaveDialog(parameters: [String: AnyCodable]) async throws -> [String: Any] {
        #if canImport(AppKit)
        return await MainActor.run {
            let panel = NSSavePanel()
            panel.title = parameters["title"]?.value as? String ?? "Save File"
            
            if let filename = parameters["defaultName"]?.value as? String {
                panel.nameFieldStringValue = filename
            }
            
            let response = panel.runModal()
            if response == .OK, let url = panel.url {
                return ["path": url.path]
            } else {
                return ["path": NSNull()]
            }
        }
        #else
        return ["path": NSNull(), "error": "File dialogs not supported on this platform"]
        #endif
    }
}

// MARK: - Shell API

public struct ShellAPI: SwiftralinoAPI {
    public let name = "shell"
    public let description = "Execute shell commands"
    
    public func execute(parameters: [String: AnyCodable]?) async throws -> [String: Any] {
        guard let parameters = parameters,
              let operation = parameters["operation"]?.value as? String else {
            throw APIError.missingParameter("operation")
        }
        
        switch operation {
        case "execute":
            guard let command = parameters["command"]?.value as? String else {
                throw APIError.missingParameter("command")
            }
            let args = (parameters["args"]?.value as? [String]) ?? []
            let workingDir = parameters["cwd"]?.value as? String
            
            return try await executeCommand(command: command, args: args, workingDir: workingDir)
            
        case "open":
            guard let path = parameters["path"]?.value as? String else {
                throw APIError.missingParameter("path")
            }
            return try await openPath(path)
            
        default:
            throw APIError.unsupportedOperation(operation)
        }
    }
    
    private func executeCommand(command: String, args: [String], workingDir: String?) async throws -> [String: Any] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = args
        
        if let workingDir = workingDir {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDir)
        }
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""
        
        return [
            "code": process.terminationStatus,
            "stdout": output,
            "stderr": error
        ]
    }
    
    private func openPath(_ path: String) async throws -> [String: Any] {
        #if canImport(AppKit)
        let _ = await MainActor.run {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }
        return ["success": true]
        #else
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xdg-open")
        process.arguments = [path]
        
        do {
            try process.run()
            return ["success": true]
        } catch {
            return ["success": false, "error": error.localizedDescription]
        }
        #endif
    }
}

// MARK: - Updater API

public struct UpdaterAPI: SwiftralinoAPI {
    public let name = "updater"
    public let description = "Application auto-updater"
    
    public func execute(parameters: [String: AnyCodable]?) async throws -> [String: Any] {
        guard let parameters = parameters,
              let operation = parameters["operation"]?.value as? String else {
            throw APIError.missingParameter("operation")
        }
        
        switch operation {
        case "checkForUpdate":
            return try await checkForUpdate()
            
        case "installUpdate":
            return try await installUpdate()
            
        case "getVersion":
            return getCurrentVersion()
            
        default:
            throw APIError.unsupportedOperation(operation)
        }
    }
    
    private func checkForUpdate() async throws -> [String: Any] {
        // This is a placeholder implementation
        // In a real app, this would check a remote server for updates
        return [
            "available": false,
            "version": "0.1.0",
            "notes": "No updates available"
        ]
    }
    
    private func installUpdate() async throws -> [String: Any] {
        // Placeholder implementation
        return [
            "success": false,
            "error": "Update installation not implemented"
        ]
    }
    
    private func getCurrentVersion() -> [String: Any] {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        return ["version": version]
    }
} 
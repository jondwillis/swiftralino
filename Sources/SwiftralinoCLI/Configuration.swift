import Foundation

/// Main configuration structure for Swiftralino projects
/// Inspired by tauri.conf.json and neutralino.config.json
public struct SwiftralinoConfig: Codable {
    public let build: BuildConfig
    public let app: AppConfig
    public let swiftralinoSettings: SwiftralinoSettings
    public let plugins: [String]
    public let bundle: BundleConfig?
    
    public init(
        build: BuildConfig = BuildConfig(),
        app: AppConfig,
        swiftralinoSettings: SwiftralinoSettings = SwiftralinoSettings(),
        plugins: [String] = [],
        bundle: BundleConfig? = nil
    ) {
        self.build = build
        self.app = app
        self.swiftralinoSettings = swiftralinoSettings
        self.plugins = plugins
        self.bundle = bundle
    }
    
    // MARK: - Static Methods
    
    /// Load configuration from swiftralino.json
    public static func load(from path: String = "swiftralino.json") throws -> SwiftralinoConfig {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(SwiftralinoConfig.self, from: data)
    }
    
    /// Save configuration to swiftralino.json
    public func save(to path: String = "swiftralino.json") throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(self)
        try data.write(to: URL(fileURLWithPath: path))
    }
    
    /// Create default configuration for a new project
    public static func defaultConfig(
        appName: String,
        identifier: String,
        template: CreateCommand.Template = .react
    ) -> SwiftralinoConfig {
        return SwiftralinoConfig(
            app: AppConfig(
                productName: appName,
                identifier: identifier,
                version: "0.1.0"
            ),
            swiftralinoSettings: SwiftralinoSettings(
                bundle: BundleOptions(
                    active: true,
                    targets: template.targets
                ),
                devPath: template.devPath,
                distDir: template.distDir
            )
        )
    }
}

// MARK: - Build Configuration

public struct BuildConfig: Codable {
    public let beforeDevCommand: String?
    public let beforeBuildCommand: String?
    public let devPath: String
    public let distDir: String
    public let withGlobalSwiftral: Bool
    
    public init(
        beforeDevCommand: String? = nil,
        beforeBuildCommand: String? = nil,
        devPath: String = "http://localhost:3000",
        distDir: String = "../dist",
        withGlobalSwiftral: Bool = false
    ) {
        self.beforeDevCommand = beforeDevCommand
        self.beforeBuildCommand = beforeBuildCommand
        self.devPath = devPath
        self.distDir = distDir
        self.withGlobalSwiftral = withGlobalSwiftral
    }
}

// MARK: - App Configuration

public struct AppConfig: Codable {
    public let productName: String
    public let identifier: String
    public let version: String
    public let description: String?
    public let authors: [String]?
    public let license: String?
    public let copyright: String?
    public let category: AppCategory?
    public let shortDescription: String?
    public let longDescription: String?
    public let windows: [WindowConfig]
    
    public init(
        productName: String,
        identifier: String,
        version: String,
        description: String? = nil,
        authors: [String]? = nil,
        license: String? = nil,
        copyright: String? = nil,
        category: AppCategory? = nil,
        shortDescription: String? = nil,
        longDescription: String? = nil,
        windows: [WindowConfig] = [WindowConfig()]
    ) {
        self.productName = productName
        self.identifier = identifier
        self.version = version
        self.description = description
        self.authors = authors
        self.license = license
        self.copyright = copyright
        self.category = category
        self.shortDescription = shortDescription
        self.longDescription = longDescription
        self.windows = windows
    }
}

public enum AppCategory: String, Codable, CaseIterable {
    case business = "Business"
    case developerTool = "DeveloperTool"
    case education = "Education"
    case entertainment = "Entertainment"
    case finance = "Finance"
    case game = "Game"
    case graphicsAndDesign = "GraphicsAndDesign"
    case healthAndFitness = "HealthAndFitness"
    case lifestyle = "Lifestyle"
    case medical = "Medical"
    case music = "Music"
    case news = "News"
    case photography = "Photography"
    case productivity = "Productivity"
    case reference = "Reference"
    case socialNetworking = "SocialNetworking"
    case sports = "Sports"
    case travel = "Travel"
    case utilities = "Utilities"
    case video = "Video"
    case weather = "Weather"
}

// MARK: - Window Configuration

public struct WindowConfig: Codable {
    public let title: String
    public let width: Int
    public let height: Int
    public let minWidth: Int?
    public let minHeight: Int?
    public let maxWidth: Int?
    public let maxHeight: Int?
    public let resizable: Bool
    public let maximizable: Bool
    public let minimizable: Bool
    public let closable: Bool
    public let alwaysOnTop: Bool
    public let fullscreen: Bool
    public let transparent: Bool
    public let decorations: Bool
    public let visible: Bool
    public let center: Bool
    
    public init(
        title: String = "Swiftralino App",
        width: Int = 1024,
        height: Int = 768,
        minWidth: Int? = 400,
        minHeight: Int? = 300,
        maxWidth: Int? = nil,
        maxHeight: Int? = nil,
        resizable: Bool = true,
        maximizable: Bool = true,
        minimizable: Bool = true,
        closable: Bool = true,
        alwaysOnTop: Bool = false,
        fullscreen: Bool = false,
        transparent: Bool = false,
        decorations: Bool = true,
        visible: Bool = true,
        center: Bool = true
    ) {
        self.title = title
        self.width = width
        self.height = height
        self.minWidth = minWidth
        self.minHeight = minHeight
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.resizable = resizable
        self.maximizable = maximizable
        self.minimizable = minimizable
        self.closable = closable
        self.alwaysOnTop = alwaysOnTop
        self.fullscreen = fullscreen
        self.transparent = transparent
        self.decorations = decorations
        self.visible = visible
        self.center = center
    }
}

// MARK: - Swiftralino Settings

public struct SwiftralinoSettings: Codable {
    public let bundle: BundleOptions
    public let allowlist: AllowlistConfig
    public let security: SecurityConfig
    public let devPath: String
    public let distDir: String
    public let withGlobalSwiftralino: Bool
    
    public init(
        bundle: BundleOptions = BundleOptions(),
        allowlist: AllowlistConfig = AllowlistConfig(),
        security: SecurityConfig = SecurityConfig(),
        devPath: String = "http://localhost:3000",
        distDir: String = "../dist",
        withGlobalSwiftralino: Bool = false
    ) {
        self.bundle = bundle
        self.allowlist = allowlist
        self.security = security
        self.devPath = devPath
        self.distDir = distDir
        self.withGlobalSwiftralino = withGlobalSwiftralino
    }
}

public struct BundleOptions: Codable {
    public let active: Bool
    public let targets: [BundleTarget]
    public let identifier: String?
    public let icon: [String]?
    public let resources: [String]?
    public let copyright: String?
    public let category: String?
    public let shortDescription: String?
    public let longDescription: String?
    
    public init(
        active: Bool = false,
        targets: [BundleTarget] = [.app],
        identifier: String? = nil,
        icon: [String]? = nil,
        resources: [String]? = nil,
        copyright: String? = nil,
        category: String? = nil,
        shortDescription: String? = nil,
        longDescription: String? = nil
    ) {
        self.active = active
        self.targets = targets
        self.identifier = identifier
        self.icon = icon
        self.resources = resources
        self.copyright = copyright
        self.category = category
        self.shortDescription = shortDescription
        self.longDescription = longDescription
    }
}

public enum BundleTarget: String, Codable, CaseIterable {
    case app = "app"
    case dmg = "dmg"
    case pkg = "pkg"
    case deb = "deb"
    case appimage = "appimage"
    case msi = "msi"
}

// MARK: - Security & Allowlist

public struct AllowlistConfig: Codable {
    public let all: Bool
    public let filesystem: FileSystemAllowlist
    public let process: ProcessAllowlist
    public let system: SystemAllowlist
    public let window: WindowAllowlist
    public let shell: ShellAllowlist
    
    public init(
        all: Bool = false,
        filesystem: FileSystemAllowlist = FileSystemAllowlist(),
        process: ProcessAllowlist = ProcessAllowlist(),
        system: SystemAllowlist = SystemAllowlist(),
        window: WindowAllowlist = WindowAllowlist(),
        shell: ShellAllowlist = ShellAllowlist()
    ) {
        self.all = all
        self.filesystem = filesystem
        self.process = process
        self.system = system
        self.window = window
        self.shell = shell
    }
}

public struct FileSystemAllowlist: Codable {
    public let all: Bool
    public let readFile: Bool
    public let writeFile: Bool
    public let readDir: Bool
    public let copyFile: Bool
    public let createDir: Bool
    public let removeDir: Bool
    public let removeFile: Bool
    public let renameFile: Bool
    public let exists: Bool
    
    public init(
        all: Bool = false,
        readFile: Bool = true,
        writeFile: Bool = false,
        readDir: Bool = true,
        copyFile: Bool = false,
        createDir: Bool = false,
        removeDir: Bool = false,
        removeFile: Bool = false,
        renameFile: Bool = false,
        exists: Bool = true
    ) {
        self.all = all
        self.readFile = readFile
        self.writeFile = writeFile
        self.readDir = readDir
        self.copyFile = copyFile
        self.createDir = createDir
        self.removeDir = removeDir
        self.removeFile = removeFile
        self.renameFile = renameFile
        self.exists = exists
    }
}

public struct ProcessAllowlist: Codable {
    public let all: Bool
    public let execute: Bool
    public let restart: Bool
    public let exit: Bool
    
    public init(
        all: Bool = false,
        execute: Bool = false,
        restart: Bool = false,
        exit: Bool = true
    ) {
        self.all = all
        self.execute = execute
        self.restart = restart
        self.exit = exit
    }
}

public struct SystemAllowlist: Codable {
    public let all: Bool
    public let version: Bool
    public let type: Bool
    public let arch: Bool
    public let tempdir: Bool
    
    public init(
        all: Bool = false,
        version: Bool = true,
        type: Bool = true,
        arch: Bool = true,
        tempdir: Bool = false
    ) {
        self.all = all
        self.version = version
        self.type = type
        self.arch = arch
        self.tempdir = tempdir
    }
}

public struct WindowAllowlist: Codable {
    public let all: Bool
    public let create: Bool
    public let center: Bool
    public let requestUserAttention: Bool
    public let setResizable: Bool
    public let setTitle: Bool
    public let maximize: Bool
    public let minimize: Bool
    public let show: Bool
    public let hide: Bool
    public let close: Bool
    
    public init(
        all: Bool = false,
        create: Bool = false,
        center: Bool = true,
        requestUserAttention: Bool = false,
        setResizable: Bool = true,
        setTitle: Bool = true,
        maximize: Bool = true,
        minimize: Bool = true,
        show: Bool = true,
        hide: Bool = true,
        close: Bool = true
    ) {
        self.all = all
        self.create = create
        self.center = center
        self.requestUserAttention = requestUserAttention
        self.setResizable = setResizable
        self.setTitle = setTitle
        self.maximize = maximize
        self.minimize = minimize
        self.show = show
        self.hide = hide
        self.close = close
    }
}

public struct ShellAllowlist: Codable {
    public let all: Bool
    public let execute: Bool
    public let sidecar: Bool
    public let open: Bool
    
    public init(
        all: Bool = false,
        execute: Bool = false,
        sidecar: Bool = false,
        open: Bool = true
    ) {
        self.all = all
        self.execute = execute
        self.sidecar = sidecar
        self.open = open
    }
}

public struct SecurityConfig: Codable {
    public let csp: String?
    public let devCsp: String?
    public let freezePrototype: Bool
    public let dangerousDisableAssetCspModification: Bool
    
    public init(
        csp: String? = "default-src 'self'; script-src 'self' 'unsafe-eval'; style-src 'self' 'unsafe-inline'",
        devCsp: String? = nil,
        freezePrototype: Bool = false,
        dangerousDisableAssetCspModification: Bool = false
    ) {
        self.csp = csp
        self.devCsp = devCsp
        self.freezePrototype = freezePrototype
        self.dangerousDisableAssetCspModification = dangerousDisableAssetCspModification
    }
}

// MARK: - Bundle Configuration

public struct BundleConfig: Codable {
    public let active: Bool
    public let targets: [String]
    public let identifier: String
    public let icon: [String]?
    public let resources: [String]?
    public let copyright: String?
    public let category: String?
    public let shortDescription: String?
    public let longDescription: String?
    public let deb: DebConfig?
    public let macos: MacOSConfig?
    public let windows: WindowsBundleConfig?
    
    public init(
        active: Bool = true,
        targets: [String] = ["app"],
        identifier: String,
        icon: [String]? = nil,
        resources: [String]? = nil,
        copyright: String? = nil,
        category: String? = nil,
        shortDescription: String? = nil,
        longDescription: String? = nil,
        deb: DebConfig? = nil,
        macos: MacOSConfig? = nil,
        windows: WindowsBundleConfig? = nil
    ) {
        self.active = active
        self.targets = targets
        self.identifier = identifier
        self.icon = icon
        self.resources = resources
        self.copyright = copyright
        self.category = category
        self.shortDescription = shortDescription
        self.longDescription = longDescription
        self.deb = deb
        self.macos = macos
        self.windows = windows
    }
}

public struct DebConfig: Codable {
    public let depends: [String]?
    public let files: [String: String]?
    
    public init(depends: [String]? = nil, files: [String: String]? = nil) {
        self.depends = depends
        self.files = files
    }
}

public struct MacOSConfig: Codable {
    public let frameworks: [String]?
    public let minimumSystemVersion: String?
    public let exceptionDomain: String?
    public let signingIdentity: String?
    public let providerShortName: String?
    public let entitlements: String?
    
    public init(
        frameworks: [String]? = nil,
        minimumSystemVersion: String? = nil,
        exceptionDomain: String? = nil,
        signingIdentity: String? = nil,
        providerShortName: String? = nil,
        entitlements: String? = nil
    ) {
        self.frameworks = frameworks
        self.minimumSystemVersion = minimumSystemVersion
        self.exceptionDomain = exceptionDomain
        self.signingIdentity = signingIdentity
        self.providerShortName = providerShortName
        self.entitlements = entitlements
    }
}

public struct WindowsBundleConfig: Codable {
    public let certificateThumbprint: String?
    public let digestAlgorithm: String?
    public let timestampUrl: String?
    public let tsp: Bool?
    public let wix: WixConfig?
    public let webviewInstallMode: WebViewInstallMode?
    
    public init(
        certificateThumbprint: String? = nil,
        digestAlgorithm: String? = "sha256",
        timestampUrl: String? = nil,
        tsp: Bool? = false,
        wix: WixConfig? = nil,
        webviewInstallMode: WebViewInstallMode? = .downloadBootstrapper
    ) {
        self.certificateThumbprint = certificateThumbprint
        self.digestAlgorithm = digestAlgorithm
        self.timestampUrl = timestampUrl
        self.tsp = tsp
        self.wix = wix
        self.webviewInstallMode = webviewInstallMode
    }
}

public struct WixConfig: Codable {
    public let language: [String]?
    public let template: String?
    public let fragmentPaths: [String]?
    public let componentGroupRefs: [String]?
    public let componentRefs: [String]?
    public let featureGroupRefs: [String]?
    public let featureRefs: [String]?
    public let mergeRefs: [String]?
    
    public init(
        language: [String]? = nil,
        template: String? = nil,
        fragmentPaths: [String]? = nil,
        componentGroupRefs: [String]? = nil,
        componentRefs: [String]? = nil,
        featureGroupRefs: [String]? = nil,
        featureRefs: [String]? = nil,
        mergeRefs: [String]? = nil
    ) {
        self.language = language
        self.template = template
        self.fragmentPaths = fragmentPaths
        self.componentGroupRefs = componentGroupRefs
        self.componentRefs = componentRefs
        self.featureGroupRefs = featureGroupRefs
        self.featureRefs = featureRefs
        self.mergeRefs = mergeRefs
    }
}

public enum WebViewInstallMode: String, Codable {
    case skip = "skip"
    case downloadBootstrapper = "downloadBootstrapper"
    case embedBootstrapper = "embedBootstrapper"
    case offlineInstaller = "offlineInstaller"
    case fixedRuntime = "fixedRuntime"
}

// MARK: - Template Extensions

extension CreateCommand.Template {
    var targets: [BundleTarget] {
        switch self {
        case .desktop: return [.app, .dmg]
        case .mobile: return [.app]
        default: return [.app]
        }
    }
    
    var devPath: String {
        switch self {
        case .vanilla: return "http://localhost:8080"
        case .react, .vue, .svelte: return "http://localhost:3000"
        case .desktop, .mobile: return "http://localhost:3000"
        }
    }
    
    var distDir: String {
        switch self {
        case .vanilla: return "../public"
        case .react, .vue, .svelte: return "../dist"
        case .desktop, .mobile: return "../dist"
        }
    }
} 
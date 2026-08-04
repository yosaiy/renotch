import AppKit
import Foundation

enum BrowserIntegrationInstaller {
    static let hostName = "com.vincentyosi.virtualnotch.browser_bridge"
    static let extensionID = "lekadelliioeecihidklkhmbmmadcklh"

    private static let hostDirectories = [
        "Google/Chrome/NativeMessagingHosts",
        "Chromium/NativeMessagingHosts",
        "BraveSoftware/Brave-Browser/NativeMessagingHosts",
        "Microsoft Edge/NativeMessagingHosts"
    ]

    static var bundledExtensionURL: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("BrowserExtension", isDirectory: true)
    }

    @discardableResult
    static func installBundledHost() throws -> Int {
        guard let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent() else {
            throw BrowserIntegrationError.missingExecutableDirectory
        }
        let bridgeURL = executableDirectory.appendingPathComponent("VirtualNotchBrowserBridge")
        guard FileManager.default.isExecutableFile(atPath: bridgeURL.path) else {
            throw BrowserIntegrationError.missingBridge
        }

        let manifest = NativeHostManifest(
            name: hostName,
            description: "Re:notch browser activity bridge",
            path: bridgeURL.path,
            type: "stdio",
            allowedOrigins: ["chrome-extension://\(extensionID)/"]
        )
        let data = try JSONEncoder.pretty.encode(manifest)
        let applicationSupport = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)

        var installed = 0
        for relativePath in hostDirectories {
            let directory = applicationSupport.appendingPathComponent(relativePath, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(
                to: directory.appendingPathComponent("\(hostName).json"),
                options: .atomic
            )
            installed += 1
        }
        return installed
    }
}

private struct NativeHostManifest: Encodable {
    let name: String
    let description: String
    let path: String
    let type: String
    let allowedOrigins: [String]

    enum CodingKeys: String, CodingKey {
        case name, description, path, type
        case allowedOrigins = "allowed_origins"
    }
}

private enum BrowserIntegrationError: LocalizedError {
    case missingExecutableDirectory
    case missingBridge

    var errorDescription: String? {
        switch self {
        case .missingExecutableDirectory: return "The application executable directory is unavailable."
        case .missingBridge: return "The bundled browser bridge is unavailable. Build the packaged app first."
        }
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

import Foundation

enum NotchMode: String, Codable {
    case compact
    case expanded
    case fileDrop
    case success
}

enum NotchAppearance: String, Codable, CaseIterable, Identifiable {
    case black
    case glassmorphism

    var id: String { rawValue }

    var title: String {
        switch self {
        case .black: return "Black"
        case .glassmorphism: return "Glassmorphism"
        }
    }
}

enum CompactNotchContent: String, Codable, CaseIterable, Identifiable {
    case music
    case servers
    case timer
    case calendar
    case shelf

    var id: String { rawValue }

    var title: String {
        switch self {
        case .music: return "Music"
        case .servers: return "Servers"
        case .timer: return "Timer"
        case .calendar: return "Calendar"
        case .shelf: return "File Shelf"
        }
    }

    var section: NotchSection {
        switch self {
        case .music: return .music
        case .servers: return .activity
        case .timer: return .timer
        case .calendar: return .calendar
        case .shelf: return .shelf
        }
    }
}

enum NotchSection: String, CaseIterable, Identifiable {
    case dashboard
    case activity
    case welcome
    case music
    case timer
    case calendar
    case clipboard
    case shelf
    case todo

    var id: String { rawValue }
}

struct NotchSettings: Codable, Equatable {
    static let notchWidthRange = 180.0...800.0
    static let compactWidthRange = notchWidthRange
    static let compactHeightRange = 28.0...300.0
    static let compactCornerRadiusRange = 0.0...40.0
    static let expandedWidthRange = notchWidthRange
    static let expandedHeightRange = 180.0...260.0
    static let codingExpandedWidth = 500.0
    static let codingExpandedHeight = 240.0
    static let dragWidth = 500.0
    static let dragHeight = 120.0

    var isEnabled = true
    var launchAtLogin = false
    var targetDisplayID: UInt32?
    var expandOnHover = true
    var expandOnClick = true
    var showOnFullscreen = true
    var alwaysOnTop = true
    /// Optional so settings written by older app versions continue to decode.
    var notchAppearance: NotchAppearance? = .black
    /// Optional so settings written before adjustable glass blur still decode.
    var glassBlurRadius: Double? = 16
    /// Optional so settings written before selectable compact content still decode.
    var compactContent: CompactNotchContent? = .music
    /// Optional so settings written before adjustable corner radius still decode.
    var compactCornerRadius: Double? = 18
    var clipboardHistoryEnabled = true
    var timerNotificationsEnabled = true
    var compactWidth = 220.0
    var compactHeight = 36.0
    var expandedWidth = 460.0
    var expandedHeight = 220.0
    var collapseDelay = 0.45
    var verticalOffset = 0.0

    static let `default` = NotchSettings()

    var resolvedAppearance: NotchAppearance {
        notchAppearance ?? .black
    }

    var resolvedGlassBlurRadius: Double {
        (glassBlurRadius ?? 16).clamped(to: 0...30)
    }

    var resolvedCompactContent: CompactNotchContent {
        compactContent ?? .music
    }

    var resolvedCompactCornerRadius: Double {
        (compactCornerRadius ?? 18).clamped(to: Self.compactCornerRadiusRange)
    }

    mutating func clampValues() {
        compactWidth = compactWidth.clamped(to: Self.compactWidthRange)
        compactHeight = compactHeight.clamped(to: Self.compactHeightRange)
        expandedWidth = expandedWidth.clamped(to: Self.expandedWidthRange)
        expandedHeight = expandedHeight.clamped(to: Self.expandedHeightRange)
        collapseDelay = collapseDelay.clamped(to: 0.3...1.2)
        verticalOffset = verticalOffset.clamped(to: 0...40)
        glassBlurRadius = resolvedGlassBlurRadius
        compactContent = resolvedCompactContent
        compactCornerRadius = resolvedCompactCornerRadius
    }
}

enum DeveloperActivityKind: String, CaseIterable, Identifiable, Codable {
    case localhost
    case build
    case docker
    case git
    case deployment
    case terminal

    var id: String { rawValue }
}

enum DeveloperActivityState: String, Codable {
    case running
    case success
    case failed
    case idle
}

struct DeveloperActivity: Identifiable, Equatable {
    let id: String
    let kind: DeveloperActivityKind
    let title: String
    let subtitle: String
    let state: DeveloperActivityState
    let progress: Double?
    let processID: Int32?
    let url: URL?
    let faviconData: Data?
    let workingDirectory: URL?
    let detail: String?

    init(
        id: String,
        kind: DeveloperActivityKind,
        title: String,
        subtitle: String,
        state: DeveloperActivityState,
        progress: Double? = nil,
        processID: Int32? = nil,
        url: URL? = nil,
        faviconData: Data? = nil,
        workingDirectory: URL? = nil,
        detail: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.state = state
        self.progress = progress
        self.processID = processID
        self.url = url
        self.faviconData = faviconData
        self.workingDirectory = workingDirectory
        self.detail = detail
    }
}

struct DockerContainer: Identifiable, Equatable {
    let id: String
    let name: String
    let status: String
    let isRunning: Bool
}

struct GitActivitySnapshot: Equatable {
    let repositoryName: String
    let branch: String
    let changedFiles: Int
    let commitSHA: String
    let ahead: Int
    let behind: Int
    let root: URL
    let remoteURL: URL?
}

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let content: String
    let createdAt: Date

    init(id: UUID = UUID(), content: String, createdAt: Date = Date()) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
    }
}

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let createdAt: Date
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.isCompleted = isCompleted
    }
}

struct ShelfItem: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let addedAt: Date
    let displayName: String
    let fileType: String?
    let fileSize: Int64?

    var isAvailable: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    static func make(from url: URL) -> ShelfItem {
        let normalizedURL = url.standardizedFileURL
        let values = try? normalizedURL.resourceValues(
            forKeys: [.nameKey, .contentTypeKey, .fileSizeKey]
        )

        return ShelfItem(
            id: UUID(),
            url: normalizedURL,
            addedAt: Date(),
            displayName: values?.name ?? normalizedURL.lastPathComponent,
            fileType: values?.contentType?.identifier,
            fileSize: values?.fileSize.map(Int64.init)
        )
    }
}

struct StoredTimer: Codable, Equatable {
    var duration: TimeInterval
    var endDate: Date
    var remainingWhenPaused: TimeInterval?

    var isPaused: Bool { remainingWhenPaused != nil }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

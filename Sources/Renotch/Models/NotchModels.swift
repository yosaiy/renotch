import Foundation

enum NotchMode: String, Codable, Sendable {
    case compact
    case expanded
    case fileDrop
    case success
    case focusTakeover
}

enum NotchAppearance: String, Codable, CaseIterable, Identifiable, Sendable {
    case black
    case liquidGlass

    var id: String { rawValue }

    var title: String {
        switch self {
        case .black: return "纯黑"
        case .liquidGlass: return "液态玻璃"
        }
    }
}

enum CompactNotchContent: String, Codable, CaseIterable, Identifiable, Sendable {
    case music
    case servers
    case codex
    case timer
    case calendar
    case shelf
    case todo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .music: return "音乐"
        case .codex: return "Codex 任务"
        case .servers: return "本地服务"
        case .timer: return "计时器"
        case .calendar: return "日历"
        case .shelf: return "文件暂存"
        case .todo: return "待办清单"
        }
    }

    var section: NotchSection {
        switch self {
        case .music: return .music
        case .codex: return .codex
        case .servers: return .activity
        case .timer: return .timer
        case .calendar: return .calendar
        case .shelf: return .shelf
        case .todo: return .todo
        }
    }
}

enum NotchSection: String, CaseIterable, Identifiable, Sendable {
    case dashboard
    case codex
    case activity
    case welcome
    case music
    case timer
    case calendar
    case shelf
    case todo

    var id: String { rawValue }
}

enum HeaderNavigationStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case standard = "topBar"
    case belowNotch = "belowNotch"
    case bottomDock = "bottomDock"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: return "顶部导航"
        case .belowNotch: return "刘海下方（安全区域）"
        case .bottomDock: return "底部导航"
        }
    }

    var subtitle: String {
        switch self {
        case .standard: return "将导航栏放在顶部"
        case .belowNotch: return "将导航栏放在实体刘海下方"
        case .bottomDock: return "在底部浮动栏中显示导航标签"
        }
    }
}

struct NotchSettings: Codable, Equatable, Sendable {
    static let notchWidthRange = 180.0...800.0
    static let compactWidthRange = notchWidthRange
    static let compactHeightRange = 28.0...300.0
    static let compactCornerRadiusRange = 0.0...40.0
    static let compactContentHorizontalPaddingRange = 0.0...100.0
    static let compactContentVerticalPaddingRange = 0.0...20.0
    static let expandedContentPaddingRange = 0.0...80.0
    static let expandedWidthRange = notchWidthRange
    static let expandedHeightRange = 180.0...800.0
    static let codingExpandedWidth = 500.0
    static let codingExpandedHeight = 240.0
    /// Narrowest width that fits the full expanded header (Dashboard button,
    /// all section tabs with labels, and the close button) without truncation.
    static let expandedMinWidth = 440.0
    static let dragWidth = 500.0
    static let dragHeight = 120.0

    static let codexExpandedWidth = 620.0
    static let codexExpandedHeight = 460.0
    var codexEnabled: Bool? = true
    var codexShowQuestions: Bool? = true
    var codexShowUsage: Bool? = true
    var codexCompletionSeconds: Double? = 120

    var isEnabled = true
    var launchAtLogin = false
    var targetDisplayID: UInt32?
    var followForegroundWindow: Bool? = false
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
    var compactCornerRadius: Double? = 11
    /// Optional so settings written before adjustable compact content padding still decode.
    var compactContentLeadingPadding: Double? = 19
    var compactContentTrailingPadding: Double? = 19
    var compactContentTopPadding: Double? = 0
    var compactContentBottomPadding: Double? = 4
    /// Optional so settings written before the compact track-info toggle still decode.
    var compactMusicShowsTrackInfo: Bool? = false
    /// Optional so settings written before adjustable expanded content padding still decode.
    var expandedContentLeadingPadding: Double? = 28
    var expandedContentTrailingPadding: Double? = 28
    var expandedContentTopPadding: Double? = 12
    var expandedContentBottomPadding: Double? = 14
    /// Optional so settings written before hardware notch accommodation still decode.
    var avoidHardwareNotch: Bool? = false
    /// Optional so settings written before configurable navigation styles still decode.
    var headerNavigationStyle: HeaderNavigationStyle? = .standard
    var timerNotificationsEnabled = true
    var focusBlockerEnabled: Bool? = true
    var focusBlockerStrictPomodoroOnly: Bool? = false
    var focusBlockerCustomRules: [String]? = [
        "threads.net",
        "instagram.com",
        "twitter.com",
        "x.com",
        "youtube.com",
        "tiktok.com",
        "reddit.com",
        "facebook.com",
        "netflix.com"
    ]
    var compactWidth = 548.0
    var compactHeight = 30.0
    var expandedWidth = 548.0
    var expandedHeight = 209.0
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
        (compactCornerRadius ?? 11).clamped(to: Self.compactCornerRadiusRange)
    }

    var resolvedCompactContentLeadingPadding: Double {
        (compactContentLeadingPadding ?? 19).clamped(to: Self.compactContentHorizontalPaddingRange)
    }

    var resolvedCompactContentTrailingPadding: Double {
        (compactContentTrailingPadding ?? 19).clamped(to: Self.compactContentHorizontalPaddingRange)
    }

    var resolvedCompactContentTopPadding: Double {
        (compactContentTopPadding ?? 0).clamped(to: Self.compactContentVerticalPaddingRange)
    }

    var resolvedCompactContentBottomPadding: Double {
        (compactContentBottomPadding ?? 4).clamped(to: Self.compactContentVerticalPaddingRange)
    }

    var resolvedCompactMusicShowsTrackInfo: Bool {
        compactMusicShowsTrackInfo ?? false
    }

    var resolvedAvoidHardwareNotch: Bool {
        avoidHardwareNotch ?? false
    }

    var resolvedHeaderNavigationStyle: HeaderNavigationStyle {
        headerNavigationStyle ?? .standard
    }

    var isHardwareNotchSafeActive: Bool {
        resolvedAvoidHardwareNotch || resolvedHeaderNavigationStyle == .belowNotch
    }

    var resolvedExpandedContentLeadingPadding: Double {
        (expandedContentLeadingPadding ?? 28).clamped(to: Self.expandedContentPaddingRange)
    }

    var resolvedExpandedContentTrailingPadding: Double {
        (expandedContentTrailingPadding ?? 28).clamped(to: Self.expandedContentPaddingRange)
    }

    var resolvedExpandedContentTopPadding: Double {
        let base = (expandedContentTopPadding ?? 12).clamped(to: Self.expandedContentPaddingRange)
        return isHardwareNotchSafeActive ? base + 26 : base
    }

    var resolvedExpandedContentBottomPadding: Double {
        (expandedContentBottomPadding ?? 14).clamped(to: Self.expandedContentPaddingRange)
    }

    var resolvedFocusBlockerEnabled: Bool {
        focusBlockerEnabled ?? true
    }

    var resolvedFocusBlockerStrictPomodoroOnly: Bool {
        focusBlockerStrictPomodoroOnly ?? false
    }

    var resolvedFocusBlockerCustomRules: [String] {
        focusBlockerCustomRules ?? [
            "threads.net",
            "instagram.com",
            "twitter.com",
            "x.com",
            "youtube.com",
            "tiktok.com",
            "reddit.com",
            "facebook.com",
            "netflix.com"
        ]
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
        compactContentLeadingPadding = resolvedCompactContentLeadingPadding
        compactContentTrailingPadding = resolvedCompactContentTrailingPadding
        compactContentTopPadding = resolvedCompactContentTopPadding
        compactContentBottomPadding = resolvedCompactContentBottomPadding
        compactMusicShowsTrackInfo = resolvedCompactMusicShowsTrackInfo
        expandedContentLeadingPadding = resolvedExpandedContentLeadingPadding
        expandedContentTrailingPadding = resolvedExpandedContentTrailingPadding
        expandedContentTopPadding = (expandedContentTopPadding ?? 12).clamped(to: Self.expandedContentPaddingRange)
        expandedContentBottomPadding = resolvedExpandedContentBottomPadding
        avoidHardwareNotch = resolvedAvoidHardwareNotch
        headerNavigationStyle = resolvedHeaderNavigationStyle
        focusBlockerEnabled = resolvedFocusBlockerEnabled
        focusBlockerStrictPomodoroOnly = resolvedFocusBlockerStrictPomodoroOnly
        focusBlockerCustomRules = resolvedFocusBlockerCustomRules
    }
}

enum DeveloperActivityKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case localhost
    case build
    case docker
    case git
    case deployment
    case terminal

    var id: String { rawValue }
}

enum DeveloperActivityState: String, Codable, Sendable {
    case running
    case success
    case failed
    case idle
}

struct DeveloperActivity: Identifiable, Equatable, Sendable {
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

struct DockerContainer: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let status: String
    let isRunning: Bool
}

struct GitActivitySnapshot: Equatable, Sendable {
    let repositoryName: String
    let branch: String
    let changedFiles: Int
    let commitSHA: String
    let ahead: Int
    let behind: Int
    let root: URL
    let remoteURL: URL?
}

struct TodoItem: Identifiable, Codable, Equatable, Sendable {
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

struct ShelfItem: Identifiable, Hashable, Sendable {
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

enum PomodoroMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case focus
    case breakTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus: return "专注"
        case .breakTime: return "休息"
        }
    }

    var icon: String {
        switch self {
        case .focus: return "timer"
        case .breakTime: return "cup.and.saucer.fill"
        }
    }

    var presets: [Int] {
        switch self {
        case .focus: return [15, 25, 45, 60]
        case .breakTime: return [5, 10, 15, 20]
        }
    }

    var defaultMinutes: Int {
        switch self {
        case .focus: return 25
        case .breakTime: return 5
        }
    }
}

struct StoredTimer: Codable, Equatable, Sendable {
    var duration: TimeInterval
    var endDate: Date
    var remainingWhenPaused: TimeInterval?
    var mode: PomodoroMode?
    var focusMinutes: Int?
    var breakMinutes: Int?
    var autoAdvance: Bool?

    var isPaused: Bool { remainingWhenPaused != nil }
    var resolvedMode: PomodoroMode { mode ?? .focus }
    var resolvedFocusMinutes: Int { focusMinutes ?? 25 }
    var resolvedBreakMinutes: Int { breakMinutes ?? 5 }
    var isAutoAdvance: Bool { autoAdvance ?? true }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

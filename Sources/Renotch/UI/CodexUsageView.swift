import SwiftUI

struct CodexUsageView: View {
    @ObservedObject var service: CodexUsageService
    @State private var showsDetails = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.bar.fill").foregroundStyle(.cyan)
            Text("剩余额度").font(.system(size: 10, weight: .semibold))
            if let windows = service.snapshot?.main?.windows, !windows.isEmpty {
                ForEach(windows) { window in
                    HStack(spacing: 4) {
                        Text(window.title).foregroundStyle(.secondary)
                        Text(window.remainingText).monospacedDigit().foregroundStyle(tint(window))
                    }.font(.system(size: 11, weight: .medium))
                }
                if service.isStale { Text("上次数据").font(.system(size: 9)).foregroundStyle(.orange) }
            } else {
                Text(service.isLoading ? "读取中…" : "暂不可用").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Button("详情") { showsDetails.toggle() }
                .buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(.secondary)
                .popover(isPresented: $showsDetails) { details }
            Button { service.refresh() } label: {
                Image(systemName: "arrow.clockwise").font(.system(size: 11))
            }.buttonStyle(.plain).disabled(service.isLoading).help("刷新用量").accessibilityLabel("刷新用量")
        }
        .padding(.horizontal, 10).padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.055)))
    }

    private var details: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Codex 剩余用量").font(.headline)
                if let snapshot = service.snapshot {
                    ForEach(snapshot.buckets) { bucket in
                        VStack(alignment: .leading, spacing: 9) {
                            Text(bucket.title).font(.system(size: 12, weight: .semibold))
                            if bucket.windows.isEmpty { Text("额度信息暂不可用").font(.caption).foregroundStyle(.secondary) }
                            ForEach(bucket.windows) { window in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(window.title)
                                        Spacer()
                                        Text("剩余 \(window.remainingText)").foregroundStyle(tint(window))
                                    }.font(.system(size: 11))
                                    if let remaining = window.remainingPercent { ProgressView(value: remaining, total: 100).tint(tint(window)) }
                                    if let reset = window.resetsAt {
                                        Text("重置时间：\(reset.formatted(.dateTime.locale(Locale(identifier: "zh_CN")).month().day().hour().minute()))")
                                            .font(.system(size: 10)).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    Text("更新时间：\(snapshot.fetchedAt.formatted(.dateTime.locale(Locale(identifier: "zh_CN")).hour().minute()))")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
                if let message = service.message { Text(message).font(.caption).foregroundStyle(.orange) }
                Text("额度由整个账号共享，每分钟自动刷新。不同模型可能使用独立额度。")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }.padding(16)
        }.frame(width: 320, height: 360)
    }

    private func tint(_ window: CodexUsageWindow) -> Color {
        guard let remaining = window.remainingPercent else { return .secondary }
        return remaining <= 10 ? .red : remaining <= 25 ? .orange : .cyan
    }
}

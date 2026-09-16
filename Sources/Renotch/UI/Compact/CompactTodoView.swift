import SwiftUI

/// Apple-designed compact widget for To-Do list in the notch bar.
/// Follows Apple Design principles: instant response, optical typography,
/// fluid spring-driven progress/check indicator, and clean hierarchy.
struct CompactTodoView: View {
    @ObservedObject var store: TodoStore
    let message: String?

    private var topPendingTask: TodoItem? {
        store.items.first(where: { !$0.isCompleted })
    }

    private var completedCount: Int {
        store.items.count - store.remainingCount
    }

    private var progress: Double {
        guard !store.items.isEmpty else { return 0 }
        return Double(completedCount) / Double(store.items.count)
    }

    var body: some View {
        HStack(spacing: 9) {
            statusBadge

            VStack(alignment: .leading, spacing: 1) {
                Text(headline)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(subline)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(Color.notchMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            trailingIndicator
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var statusBadge: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 2)

            if !store.items.isEmpty && store.remainingCount == 0 {
                Circle()
                    .fill(Color.notchAccent.opacity(0.18))
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.notchAccent)
            } else if !store.items.isEmpty {
                if progress > 0 {
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(
                            Color.notchAccent,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: progress)
                }
                Image(systemName: "checklist")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.notchAccent)
            } else {
                Image(systemName: "checklist")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.notchAccent.opacity(0.85))
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }

    private var headline: String {
        if let message { return message }
        if let top = topPendingTask {
            return top.title
        }
        if store.items.isEmpty {
            return "暂无待办"
        }
        return "所有待办均已完成"
    }

    private var subline: String {
        if store.items.isEmpty {
            return "点击添加第一条待办"
        }
        if store.remainingCount == 0 {
            return "今天已完成 \(store.items.count) 项 · 待办已清空"
        }
        if completedCount > 0 {
            return "剩余 \(store.remainingCount) 项 · 已完成 \(completedCount) 项"
        }
        return "还有 \(store.remainingCount) 项待办"
    }

    @ViewBuilder
    private var trailingIndicator: some View {
        if store.items.isEmpty {
            Image(systemName: "plus")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.white.opacity(0.06)))
        } else if store.remainingCount == 0 {
            HStack(spacing: 3) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.notchAccent)
                Text("完成")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.notchAccent)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.notchAccent.opacity(0.12))
            )
        } else {
            HStack(spacing: 3.5) {
                Text("\(store.remainingCount)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.smooth(duration: 0.25), value: store.remainingCount)

                Text("剩余")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(Color.notchMuted)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
        }
    }

    private var accessibilityText: String {
        if store.items.isEmpty {
            return "待办清单为空，点击添加待办。"
        }
        if store.remainingCount == 0 {
            return "全部 \(store.items.count) 项待办均已完成。"
        }
        return "待办：\(headline)。共 \(store.items.count) 项，剩余 \(store.remainingCount) 项。"
    }
}

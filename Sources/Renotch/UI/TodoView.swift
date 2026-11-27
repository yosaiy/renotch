import AppKit
import SwiftUI

struct TodoView: View {
    @ObservedObject var store: TodoStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft = ""
    @State private var isClearHovered = false
    @FocusState private var isInputFocused: Bool

    private var completedCount: Int {
        store.items.count - store.remainingCount
    }

    private var completionRatio: Double {
        guard !store.items.isEmpty else { return 0 }
        return Double(completedCount) / Double(store.items.count)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Left Focal Summary Rail
            summaryRail
                .frame(width: 120, alignment: .leading)

            // Structural Hairline Divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
                .padding(.vertical, 2)

            // Right Workspace: Inline Composer + Hairline List
            VStack(spacing: 0) {
                composer
                    .padding(.bottom, 6)

                Rectangle()
                    .fill(Color.white.opacity(isInputFocused ? 0.22 : 0.08))
                    .frame(height: 1)
                    .animation(.easeOut(duration: 0.14), value: isInputFocused)

                if store.items.isEmpty {
                    emptyState
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                                if index > 0 {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.06))
                                        .frame(height: 1)
                                }
                                TodoRow(item: item, store: store)
                                    .transition(
                                        reduceMotion
                                            ? .opacity
                                            : .opacity.combined(with: .move(edge: .top))
                                    )
                            }
                        }
                    }
                    .animation(reduceMotion ? nil : .snappy(duration: 0.24), value: store.items)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Left Summary Rail

    private var summaryRail: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(store.remainingCount == 0 && !store.items.isEmpty ? "Completed" : "Remaining")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.notchMuted)

            Spacer(minLength: 2)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(store.remainingCount)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(store.remainingCount == 0 && !store.items.isEmpty ? Color.notchAccent : .white)
                    .contentTransition(reduceMotion ? .identity : .numericText())

                if !store.items.isEmpty {
                    Text("/ \(store.items.count)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.notchMuted)
                }
            }

            if !store.items.isEmpty {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(Color.white.opacity(0.1))
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(Color.notchAccent)
                            .frame(width: max(0, proxy.size.width * completionRatio))
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.24), value: completionRatio)
                    }
                }
                .frame(height: 3)
                .padding(.top, 6)
            }

            Spacer(minLength: 8)

            if store.hasCompletedItems {
                Button {
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
                        store.clearCompleted()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 9.5, weight: .semibold))
                        Text("Clear done")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(isClearHovered ? .white : Color.notchMuted)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(isClearHovered ? 0.12 : 0.06))
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(NotchPressButtonStyle())
                .onHover { isClearHovered = $0 }
                .help("Remove all completed tasks")
            } else {
                Text(store.items.isEmpty ? "No tasks yet" : "\(completedCount) done")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Color.notchMuted)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Inline Composer

    private var composer: some View {
        let canAdd = !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isInputFocused ? Color.notchAccent : Color.notchMuted)

            TextField("Add a task and press Return…", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.white)
                .focused($isInputFocused)
                .onSubmit(addTodo)

            if canAdd {
                Button(action: addTodo) {
                    Text("Add")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 9)
                        .frame(height: 20)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.notchAccent)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(NotchPressButtonStyle())
                .transition(.opacity)
            }
        }
        .frame(height: 26)
        .animation(.easeOut(duration: 0.14), value: canAdd)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 3) {
            Spacer()
            Text("Nothing on your list")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
            Text("Type a task above and press Return to add it.")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(Color.notchMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private func addTodo() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.85)) {
            guard store.add(draft) else { return }
            draft = ""
            isInputFocused = true
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        }
    }
}

// MARK: - Flat Hairline Todo Row

private struct TodoRow: View {
    let item: TodoItem
    @ObservedObject var store: TodoStore
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Button {
                toggleItem()
            } label: {
                ZStack {
                    if item.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(Color.notchAccent)
                    } else {
                        Circle()
                            .stroke(isHovering ? Color.notchAccent : Color.white.opacity(0.32), lineWidth: 1.3)
                            .frame(width: 13.5, height: 13.5)
                    }
                }
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
            }
            .buttonStyle(NotchPressButtonStyle())
            .help(item.isCompleted ? "Mark as incomplete" : "Mark as complete")
            .accessibilityLabel(item.isCompleted ? "Mark \(item.title) incomplete" : "Complete \(item.title)")

            Text(item.title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(item.isCompleted ? Color.white.opacity(0.56) : .white)
                .strikethrough(item.isCompleted, color: Color.white.opacity(0.4))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    store.remove(item)
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Color.notchDanger)
                    .frame(width: 20, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.notchDanger.opacity(0.14))
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .buttonStyle(NotchPressButtonStyle())
            .opacity(isHovering ? 1 : 0)
            .allowsHitTesting(isHovering)
            .help("Delete task")
            .accessibilityLabel("Delete \(item.title)")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(isHovering ? 0.055 : 0.0))
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }

    private func toggleItem() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
            store.toggle(item)
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        }
    }
}

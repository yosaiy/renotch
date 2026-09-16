import SwiftUI
import AppKit

struct TodoView: View {
    @ObservedObject var store: TodoStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            // Apple-style Input Composer
            composer

            // Status Bar (Remaining count & Clear completed)
            if !store.items.isEmpty {
                statusBar
            }

            // Task List or Empty State
            if store.items.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 5) {
                        ForEach(store.items) { item in
                            TodoRow(item: item, store: store)
                                .transition(
                                    reduceMotion
                                        ? .opacity
                                        : .asymmetric(
                                            insertion: .opacity.combined(with: .move(edge: .top)),
                                            removal: .opacity.combined(with: .scale(scale: 0.92))
                                        )
                                )
                        }
                    }
                    .padding(.vertical, 2)
                }
                .animation(.snappy(duration: 0.28), value: store.items)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isInputFocused ? Color.blue : Color.white.opacity(0.4))
                .animation(.easeOut(duration: 0.16), value: isInputFocused)

            TextField("添加一条待办…", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .focused($isInputFocused)
                .onSubmit(addTodo)

            if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(action: addTodo) {
                    HStack(spacing: 3) {
                        Text("添加")
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "return")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .padding(.horizontal, 9)
                    .frame(height: 22)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(isInputFocused ? 0.08 : 0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isInputFocused ? Color.blue.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 0.8)
                )
        )
        .animation(.easeOut(duration: 0.16), value: isInputFocused)
        .animation(.easeOut(duration: 0.16), value: draft.isEmpty)
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                Circle()
                    .fill(store.remainingCount == 0 ? Color.green : Color.blue)
                    .frame(width: 5, height: 5)

                Text(store.remainingCount == 0 ? "全部完成" : "剩余 \(store.remainingCount) 项")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(Color.white.opacity(0.04))
            .clipShape(Capsule())

            Spacer()

            if store.hasCompletedItems {
                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        store.clearCompleted()
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 9.5))
                        Text("清除已完成")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 44, height: 44)

                Image(systemName: "checklist.checked")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.blue.opacity(0.8))
            }

            VStack(spacing: 2) {
                Text("暂无待办")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))

                Text("在上方输入内容，按回车添加待办。")
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func addTodo() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            guard store.add(draft) else { return }
            draft = ""
            isInputFocused = true
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        }
    }
}

// MARK: - Apple Design Todo Row

private struct TodoRow: View {
    let item: TodoItem
    @ObservedObject var store: TodoStore
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 9) {
            // Interactive Apple Reminders Checkbox
            Button {
                toggleItem()
            } label: {
                ZStack {
                    if item.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.blue)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                    } else {
                        Circle()
                            .stroke(isHovering ? Color.white.opacity(0.45) : Color.white.opacity(0.22), lineWidth: 1.4)
                            .frame(width: 14, height: 14)
                    }
                }
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Todo Title
            Text(item.title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(item.isCompleted ? Color.white.opacity(0.38) : Color.white)
                .strikethrough(item.isCompleted, color: Color.white.opacity(0.3))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeOut(duration: 0.16), value: item.isCompleted)

            // Hover Delete Button
            if isHovering {
                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        store.remove(item)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.red.opacity(0.8))
                        .padding(4)
                        .background(Color.red.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(isHovering ? 0.07 : (item.isCompleted ? 0.025 : 0.045)))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.white.opacity(isHovering ? 0.1 : 0.04), lineWidth: 0.5)
                )
        )
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.14), value: isHovering)
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func toggleItem() {
        withAnimation(.spring(response: 0.26, dampingFraction: 0.72)) {
            store.toggle(item)
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        }
    }
}

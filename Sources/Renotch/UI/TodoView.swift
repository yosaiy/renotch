import SwiftUI

struct TodoView: View {
    @ObservedObject var store: TodoStore
    @State private var draft = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 6) {
            composer

            if store.items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(store.items) { item in
                            TodoRow(item: item, store: store)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var composer: some View {
        HStack(spacing: 7) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.notchAccent)

            TextField("Create a to-do…", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .focused($isInputFocused)
                .onSubmit(addTodo)

            if store.hasCompletedItems {
                Button {
                    store.clearCompleted()
                } label: {
                    Image(systemName: "checkmark.circle.badge.xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear completed")
            }

            Button(action: addTodo) {
                Text("Add")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.black)
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background(
                        Capsule().fill(
                            draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.white.opacity(0.08)
                                : Color.notchAccent
                        )
                    )
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var emptyState: some View {
        HStack(spacing: 7) {
            Image(systemName: "checklist")
                .foregroundStyle(Color.notchMuted)
            Text("Add your first task")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func addTodo() {
        guard store.add(draft) else { return }
        draft = ""
        isInputFocused = true
    }
}

private struct TodoRow: View {
    let item: TodoItem
    @ObservedObject var store: TodoStore

    var body: some View {
        HStack(spacing: 8) {
            Button {
                store.toggle(item)
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(item.isCompleted ? Color.notchAccent : Color.notchMuted)
            }
            .buttonStyle(.plain)

            Text(item.title)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(item.isCompleted ? Color.white.opacity(0.45) : Color.white)
                .strikethrough(item.isCompleted, color: .secondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Button {
                store.remove(item)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 9)
        .frame(height: 26)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
    }
}

import SwiftUI
import AppKit

struct FileExplorerView: View {
    @ObservedObject var store: FileExplorerStore
    @Binding var isCollapsed: Bool

    init(store: FileExplorerStore, isCollapsed: Binding<Bool>) {
        _store = ObservedObject(wrappedValue: store)
        _isCollapsed = isCollapsed
    }

    var body: some View {
        Group {
            if isCollapsed {
                collapsedSidebar
            } else {
                expandedSidebar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var expandedSidebar: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            if store.selectedTab == .folder, let folderName = store.currentFolderName {
                folderHeader(name: folderName, path: store.currentFolderPath)
                Divider()
            }
            content
        }
    }

    private var collapsedSidebar: some View {
        VStack(spacing: 0) {
            toggleButton(isCollapsed: true)
                .padding(.top, 8)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            tabButton(
                systemName: "folder",
                isSelected: store.selectedTab == .folder,
                label: "Folder"
            ) {
                store.selectTab(.folder)
            }

            tabButton(
                systemName: "clock.arrow.circlepath",
                isSelected: store.selectedTab == .history,
                label: "History"
            ) {
                store.selectTab(.history)
            }

            Spacer(minLength: 0)

            toggleButton(isCollapsed: false)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func folderHeader(name: String, path: String?) -> some View {
        HStack(spacing: 6) {
            Button {
                store.navigateUp()
            } label: {
                Image(systemName: "arrow.up.left")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(store.canNavigateUp ? .secondary : .tertiary)
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.secondary.opacity(store.canNavigateUp ? 0.08 : 0.04))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!store.canNavigateUp)
            .help("Up")
            .accessibilityLabel("Up")

            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .help(path ?? name)
    }

    @ViewBuilder
    private var content: some View {
        let items = store.visibleItems
        if items.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(items) { item in
                        explorerRow(item)
                    }
                }
                .padding(8)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(store.emptyStateText)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
    }

    private func explorerRow(_ item: FileExplorerItem) -> some View {
        Button {
            store.activate(item)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: item.isDirectory ? "folder" : "doc.text")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(item.isCurrentFile ? Color.accentColor : Color.secondary)
                    .frame(width: 16, alignment: .leading)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let subtitle = item.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(item.isCurrentFile ? Color.accentColor.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .help(item.subtitle.map { "\(item.title) — \($0)" } ?? item.title)
        .accessibilityLabel(item.subtitle.map { "\(item.title), \($0)" } ?? item.title)
    }

    private func tabButton(
        systemName: String,
        isSelected: Bool,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }

    private func toggleButton(isCollapsed: Bool) -> some View {
        Button {
            self.isCollapsed.toggle()
        } label: {
            Image(systemName: "sidebar.left")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Color.secondary)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .help(isCollapsed ? "Show Sidebar" : "Hide Sidebar")
        .accessibilityLabel(isCollapsed ? "Show Sidebar" : "Hide Sidebar")
    }
}

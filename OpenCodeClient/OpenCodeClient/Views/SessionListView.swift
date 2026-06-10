//
//  SessionListView.swift
//  OpenCodeClient
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SessionListView: View {
    @Bindable var state: AppState
    @State private var pendingDeleteSession: Session?
    @State private var deletingSessionID: String?
    @State private var deleteError: String?
    @State private var showCreateInfoAlert = false

    var body: some View {
        NavigationStack {
            Group {
                if state.sidebarSessions.isEmpty {
                    ContentUnavailableView(
                        L10n.t(.sessionsEmptyTitle),
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text(L10n.t(.sessionsEmptyDescription))
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        sessionNodes(state.sessionTree)

                        if state.isLoadingMoreSessions {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .listRowSeparator(.hidden)
                        } else if state.canLoadMoreSessions, let lastSessionID = state.sidebarSessions.last?.id {
                            Color.clear
                                .frame(height: 1)
                                .listRowSeparator(.hidden)
                                .onAppear {
                                    Task { await state.loadMoreSessions() }
                                }
                            .id("load-more-\(lastSessionID)")
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemGroupedBackground))
                    .accessibilityIdentifier("session-list")
                    .refreshable {
                        await state.refreshSessions()
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L10n.t(.sessionsTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showCreateInfoAlert = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .foregroundColor(.secondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await state.createSession()
                            state.selectedTab = 1
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(!state.canCreateSession)
                    .foregroundColor(state.canCreateSession ? .accentColor : .gray)
                }
            }
        }
        .alert(
            L10n.t(.sessionsDeleteConfirmTitle),
            isPresented: Binding(
                get: { pendingDeleteSession != nil },
                set: { if !$0 { pendingDeleteSession = nil } }
            ),
            presenting: pendingDeleteSession
        ) { session in
            Button(L10n.t(.commonCancel), role: .cancel) {}
            Button(L10n.t(.sessionsDelete), role: .destructive) {
                confirmDelete(session)
            }
        } message: { session in
            Text(L10n.t(.sessionsDeleteConfirmMessage))
        }
        .alert(
            L10n.t(.sessionsDeleteFailedTitle),
            isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )
        ) {
            Button(L10n.t(.commonOk)) {
                deleteError = nil
            }
        } message: {
            if let deleteError {
                Text(deleteError)
            }
        }
        .task {
            await state.refreshSessions()
        }
        .alert(L10n.t(.sessionsTitle), isPresented: $showCreateInfoAlert) {
            Button(L10n.t(.commonOk)) {}
        } message: {
            Text(state.canCreateSession ? L10n.t(.sessionsEmptyDescription) : state.createSessionDisabledHint)
        }
    }

    private func selectSession(_ session: Session) {
        state.selectSession(session)
        state.selectedTab = 1
    }

    private func sessionNodes(_ nodes: [SessionNode], depth: Int = 0) -> AnyView {
        AnyView(
            ForEach(nodes) { node in
                let session = node.session
                let status = state.sessionStatuses[session.id]

                SessionRowView(
                    session: session,
                    status: status,
                    isSelected: state.currentSessionID == session.id,
                    isDeleting: deletingSessionID == session.id,
                    depth: depth,
                    hasChildren: !node.children.isEmpty,
                    isCollapsed: !state.expandedSessionIDs.contains(session.id),
                    onSelect: { selectSession(session) },
                    onToggleCollapse: { state.toggleSessionExpanded(session.id) }
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        pendingDeleteSession = session
                    } label: {
                        Label(L10n.t(.sessionsDelete), systemImage: "trash")
                    }
                    .tint(.red)
                    .disabled(deletingSessionID != nil)
                }

                if state.expandedSessionIDs.contains(session.id) {
                    sessionNodes(node.children, depth: depth + 1)
                }
            }
        )
    }

    private func confirmDelete(_ session: Session) {
        guard deletingSessionID == nil else { return }
        deletingSessionID = session.id
        Task {
            do {
                try await state.deleteSession(sessionID: session.id)
            } catch {
                deleteError = error.localizedDescription
            }
            deletingSessionID = nil
        }
    }
}

struct SessionRowView: View {
    let session: Session
    let status: SessionStatus?
    let isSelected: Bool
    let isDeleting: Bool
    var depth: Int = 0
    var hasChildren: Bool = false
    var isCollapsed: Bool = false
    let onSelect: () -> Void
    var onToggleCollapse: (() -> Void)? = nil
    
    private var isBusy: Bool {
        guard let status else { return false }
        return status.type == "busy" || status.type == "retry"
    }

    private var rowAccent: Color {
        if isSelected { return .accentColor }
        guard let status else { return .secondary }
        return statusColor(status)
    }

    private var rowIndent: CGFloat {
        CGFloat(min(max(depth, 0), 2)) * 14
    }

    var body: some View {
        HStack(spacing: 10) {
            if rowIndent > 0 {
                Color.clear
                    .frame(width: rowIndent)
                    .accessibilityHidden(true)
            }

            if hasChildren {
                Button {
                    onToggleCollapse?()
                } label: {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 14)
                .accessibilityIdentifier("session-toggle-\(session.id)")
            } else {
                Color.clear
                    .frame(width: 14)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(rowAccent.opacity(isSelected ? 0.16 : 0.11))
                    .frame(width: 34, height: 34)

                Image(systemName: hasChildren ? "bubble.left.and.bubble.right.fill" : "bubble.left.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(rowAccent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(session.title.isEmpty ? L10n.t(.sessionsUntitled) : session.title)
                    .font(depth > 0 ? .footnote.weight(.semibold) : .subheadline.weight(.semibold))
                    .foregroundStyle(isBusy ? Color.blue : Color.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(formattedDate(session.time.updated))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if let status {
                        Text(statusLabel(status))
                            .font(.caption2)
                            .foregroundStyle(statusColor(status))
                    }
                }
            }

            Spacer()

            if isDeleting {
                ProgressView()
                    .controlSize(.small)
            } else if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.22) : Color(.separator).opacity(0.18), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isDeleting else { return }
            onSelect()
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("session-row-\(session.id)")
    }

    private func formattedDate(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale.current
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func statusLabel(_ status: SessionStatus) -> String {
        switch status.type {
        case "busy": return L10n.t(.sessionsStatusBusy)
        case "retry": return L10n.t(.sessionsStatusRetry)
        default: return L10n.t(.sessionsStatusIdle)
        }
    }

    private func statusColor(_ status: SessionStatus) -> Color {
        switch status.type {
        case "busy", "retry": return .blue
        default: return .secondary
        }
    }
}

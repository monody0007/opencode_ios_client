//
//  ChatToolbarView.swift
//  OpenCodeClient
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ChatToolbarView: View {
    @Bindable var state: AppState
    @Binding var showRenameAlert: Bool
    @Binding var renameText: String
    var showSettingsInToolbar: Bool
    var onSettingsTap: (() -> Void)?

    private var useCompactLabels: Bool {
#if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .phone
#else
        return false
#endif
    }

    private var currentTitle: String {
        let title = state.currentSession?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? L10n.t(.appChat) : title
    }

    private var titleMaxWidth: CGFloat {
        useCompactLabels ? 150 : 280
    }

    private var modelLabelMaxWidth: CGFloat {
        useCompactLabels ? 82 : 180
    }

    var body: some View {
        HStack(spacing: 8) {
            titleEditButton
                .layoutPriority(1)

            Spacer(minLength: 0)

            Text(currentTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: titleMaxWidth)
                .accessibilityIdentifier("chat-title")

            Spacer(minLength: 0)

            rightButtons
                .layoutPriority(1)
        }
        .frame(minHeight: 38)
        .padding(.horizontal, LayoutConstants.Spacing.comfortable)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private var titleEditButton: some View {
        Button {
            renameText = state.currentSession?.title ?? ""
            showRenameAlert = true
        } label: {
            Image(systemName: "pencil.circle")
                .font(.body)
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(.accentColor)
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
    }

    private var rightButtons: some View {
        HStack(spacing: LayoutConstants.Toolbar.modelButtonSpacing) {
            ContextUsageButton(state: state)
            modelMenu

            if showSettingsInToolbar, let onSettingsTap {
                Button {
                    onSettingsTap()
                } label: {
                    Image(systemName: "gear")
                        .font(.body)
                        .symbolRenderingMode(.hierarchical)
                }
                .frame(width: 34, height: 34)
            }
        }
    }

    private var modelMenu: some View {
        Menu {
            Section("Model") {
                ForEach(Array(state.modelPresets.enumerated()), id: \.element.id) { index, preset in
                    Button {
                        state.setSelectedModelIndex(index)
                    } label: {
                        HStack {
                            Text(preset.displayName)
                            if state.selectedModelIndex == index {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Section("Agent") {
                if state.isLoadingAgents {
                    ProgressView()
                } else if state.visibleAgents.isEmpty {
                    Text("No agents available")
                } else {
                    ForEach(Array(state.visibleAgents.enumerated()), id: \.element.id) { index, agent in
                        Button {
                            state.setSelectedAgentIndex(index)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(agent.shortName)
                                    if !useCompactLabels, let desc = agent.description, !desc.isEmpty {
                                        Text(desc)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                if state.selectedAgentIndex == index {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(useCompactLabels ? (state.selectedModel?.shortName ?? "Model") : (state.selectedModel?.displayName ?? "Model"))
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: modelLabelMaxWidth)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.accentColor.gradient)
            .foregroundColor(.white)
            .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("\(state.selectedModel?.displayName ?? "Model"), \(state.selectedAgent?.shortName ?? "Agent")")
    }
}

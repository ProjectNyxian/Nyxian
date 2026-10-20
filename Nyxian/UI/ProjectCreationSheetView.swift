/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2026 Kyle-Ye
 Copyright (C) 2026 emexlab

 This file is part of Nyxian.

 Licensed under the emexLabs Public Source License, version 1.1
 (EPSL 1.1).

 Private use and modification are permitted under the license.
 Redistribution of source or binaries, modified or unmodified,
 requires prior written permission from emexLabs.

 External deployment is subject to the source-availability
 requirements and other conditions of the license.

 Provided "AS IS", without warranty, to the extent permitted by law.

 See LICENSE for the full license terms.
*/

import SwiftUI

enum ProjectCreationStep {
    case template
    case options
}

struct ProjectCreationSheetView: View {
    @ObservedObject var model: ProjectTemplateOptionsModel
    let onCancel: () -> Void
    let onCreate: () -> Void
    
    init(model: ProjectTemplateOptionsModel, onCancel: @escaping () -> Void, onCreate: @escaping () -> Void) {
        self.model = model
        self.onCancel = onCancel
        self.onCreate = onCreate
        
        NXWindowServer.shared().unfocusFocusedWindow()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle()
                .fill(Color(uiColor: LDETheme.currentTheme!.gutterHairlineColor))
                .frame(height: 1 / UIScreen.main.scale)
            ScrollView {
                Group {
                    if model.step == .template {
                        ProjectTemplateSelectionView(model: model)
                    } else {
                        ProjectTemplateOptionsView(model: model)
                    }
                }
                .padding(.vertical, 16)
            }
            Rectangle()
                .fill(Color(uiColor: LDETheme.currentTheme!.gutterHairlineColor))
                .frame(height: 1 / UIScreen.main.scale)
            controls
        }
        .background(Color(uiColor: LDETheme.currentTheme!.backgroundColor))
        .onAppear {
            NXWindowServer.shared().windowsGetOutOfMyWay()
        }
        .onDisappear {
            NXWindowServer.shared().windowsGetInMyWay()
        }
    }
    
    private var header: some View {
        Text(model.step == .template ? "Choose a template for your new project" : "Choose options for your new project")
            .font(.title3.weight(.semibold))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)
            .foregroundColor(Color(LDETheme.currentTheme!.textColor))
    }
    
    private var controls: some View {
        HStack(spacing: 12) {
            Button("Cancel", action: onCancel)
                .projectCreationSecondaryButtonStyle()
            
            Spacer(minLength: 12)
            
            if model.step == .options {
                Button("Previous") {
                    withAnimation(.snappy) { model.step = .template }
                }
                .projectCreationSecondaryButtonStyle()
            }
            
            Button(model.step == .template ? "Next" : "Create") {
                if model.step == .template {
                    withAnimation(.snappy) { model.step = .options }
                } else {
                    onCreate()
                }
            }
            .projectCreationPrimaryButtonStyle()
        }
        .controlSize(.large)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

private struct ProjectCreationLegacyPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .foregroundStyle(Color(uiColor: LDETheme.currentTheme!.backgroundColor))
            .background {
                Capsule(style: .continuous)
                    .fill(Color(uiColor: LDETheme.currentTheme!.textColor))
                    .opacity(buttonOpacity(isPressed: configuration.isPressed))
            }
    }

    private func buttonOpacity(isPressed: Bool) -> Double {
        if !isEnabled {
            return 0.25
        }

        return isPressed ? 0.72 : 1
    }
}

private struct ProjectCreationPrimaryButtonModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .buttonStyle(ProjectCreationLegacyPrimaryButtonStyle())
    }
}

extension View {
    func projectCreationPrimaryButtonStyle() -> some View {
        modifier(ProjectCreationPrimaryButtonModifier())
    }
}

private struct ProjectCreationLegacySecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .foregroundStyle(Color(uiColor: LDETheme.currentTheme!.textColor))
            .background {
                Capsule(style: .continuous)
                    .fill(Color(uiColor: LDETheme.currentTheme!.backgroundColor))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(
                                Color(uiColor: LDETheme.currentTheme!.gutterHairlineColor),
                                lineWidth: 1
                            )
                    }
                    .opacity(buttonOpacity(isPressed: configuration.isPressed))
            }
    }

    private func buttonOpacity(isPressed: Bool) -> Double {
        if !isEnabled { return 0.25 }
        return isPressed ? 0.72 : 1
    }
}

private struct ProjectCreationSecondaryButtonModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .buttonStyle(ProjectCreationLegacySecondaryButtonStyle())
    }
}

extension View {
    func projectCreationSecondaryButtonStyle() -> some View {
        modifier(ProjectCreationSecondaryButtonModifier())
    }
}

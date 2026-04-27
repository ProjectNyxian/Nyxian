/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2026 Kyle-Ye
 Copyright (C) 2026 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
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
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle()
                .fill(Color(uiColor: currentTheme!.gutterHairlineColor))
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
                .fill(Color(uiColor: currentTheme!.gutterHairlineColor))
                .frame(height: 1 / UIScreen.main.scale)
            controls
        }
        .background(Color(uiColor: currentTheme!.backgroundColor))
    }
    
    private var header: some View {
        Text(model.step == .template ? "Choose a template for your new project" : "Choose options for your new project")
            .font(.title3.weight(.semibold))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)
            .foregroundColor(Color(currentTheme!.textColor))
    }
    
    private var controls: some View {
        HStack(spacing: 12) {
            Button("Cancel", action: onCancel)
                .buttonStyle(ProjectCreationSecondaryButtonStyle())
            
            Spacer(minLength: 12)
            
            if model.step == .options {
                Button("Previous") {
                    withAnimation(.snappy) { model.step = .template }
                }
                .buttonStyle(ProjectCreationSecondaryButtonStyle())
            }
            
            Button(model.step == .template ? "Next" : "Create") {
                if model.step == .template {
                    withAnimation(.snappy) { model.step = .options }
                } else {
                    onCreate()
                }
            }
            .buttonStyle(ProjectCreationPrimaryButtonStyle())
        }
        .controlSize(.large)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

private struct ProjectCreationPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .foregroundStyle(Color(uiColor: currentTheme!.backgroundColor))
            .background {
                Capsule(style: .continuous)
                    .fill(Color(uiColor: currentTheme!.textColor))
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

private struct ProjectCreationSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .foregroundStyle(Color(uiColor: currentTheme!.textColor))
            .background {
                Capsule(style: .continuous)
                    .fill(Color(uiColor: currentTheme!.backgroundColor))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(
                                Color(uiColor: currentTheme!.gutterHairlineColor),
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

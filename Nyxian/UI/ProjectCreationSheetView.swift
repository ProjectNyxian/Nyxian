/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2026 Kyle-Ye

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
            Divider()
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
            Divider()
            controls
        }
        .background(Color(uiColor: .systemBackground))
    }

    private var header: some View {
        Text(model.step == .template ? "Choose a template for your new project:" : "Choose options for your new project:")
            .font(.title3.weight(.semibold))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button("Cancel", action: onCancel)
                .buttonStyle(.bordered)

            Spacer(minLength: 12)

            if model.step == .options {
                Button("Previous") {
                    withAnimation(.snappy) {
                        model.step = .template
                    }
                }
                .buttonStyle(.bordered)
            }

            Button(model.step == .template ? "Next" : "Create") {
                if model.step == .template {
                    withAnimation(.snappy) {
                        model.step = .options
                    }
                } else {
                    onCreate()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .controlSize(.large)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

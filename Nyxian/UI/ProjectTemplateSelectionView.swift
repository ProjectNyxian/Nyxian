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

struct ProjectTemplateSelectionView: View {
    @ObservedObject var model: ProjectTemplateOptionsModel

    private var selectedAccentColor: Color {
        Color(uiColor: .label)
    }

    private var selectedIconForegroundColor: Color {
        Color(uiColor: .systemBackground)
    }

    private var unselectedIconForegroundColor: Color {
        Color(uiColor: .secondaryLabel)
    }

    var body: some View {
        VStack(spacing: 8) {
            templateRow(
                title: "App",
                subtitle: "Application project",
                systemImage: "app.badge",
                projectType: .app
            )

            templateRow(
                title: "Utility",
                subtitle: "Command line tool",
                systemImage: "terminal",
                projectType: .utility
            )
        }
        .padding(.top, 2)
        .padding(.horizontal, 18)
        .padding(.bottom, 6)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func templateRow(title: String,
                             subtitle: String,
                             systemImage: String,
                             projectType: NXProjectType) -> some View {
        let isSelected = model.projectType == projectType

        return Button {
            model.selectProjectType(projectType)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? selectedAccentColor : Color(uiColor: .tertiarySystemFill))
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(isSelected ? selectedIconForegroundColor : unselectedIconForegroundColor)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? selectedAccentColor : Color(uiColor: .tertiaryLabel))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(isSelected ? selectedAccentColor : Color.clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

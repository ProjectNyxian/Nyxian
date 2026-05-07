/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2026 Kyle-Ye
 Copyright (C) 2026 mach-port-t

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
    
    private var textColor: Color { Color(uiColor: currentTheme!.textColor) }
    private var backgroundColor: Color { Color(uiColor: currentTheme!.backgroundColor) }
    private var hairlineColor: Color { Color(uiColor: currentTheme!.gutterHairlineColor) }
    
    var body: some View {
        VStack(spacing: 8) {
            templateRow(
                title: "App",
                subtitle: "Application project",
                systemImage: "appstore.app.fill",
                schemeKind: .app,
                scale: .large
            )
            
            templateRow(
                title: "Utility",
                subtitle: "Command line tool project",
                systemImage: "terminal.fill",
                schemeKind: .utility
            )
            
            templateRow(
                title: "Library",
                subtitle: "Library project",
                systemImage: "building.columns.fill",
                schemeKind: .library,
                isEnabled: false
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
                             schemeKind: NXProjectSchemeKind,
                             scale: UIImage.SymbolScale = .default,
                             isEnabled: Bool = true) -> some View {
        let isSelected = model.schemeKind == schemeKind
        
        return Button {
            model.selectProjectType(schemeKind)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? textColor : textColor.opacity(0.08))
                    
                    let base = UIImage(systemName: systemImage) ?? UIImage(privateSystemName: systemImage)
                    let configuredBase: UIImage? = base.applyingSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold, scale: scale))
                    let img = configuredBase?.withRenderingMode(.alwaysTemplate) ?? UIImage()
                    
                    Image(uiImage: img)
                        .font(.system(size: 22, weight: .semibold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(isSelected ? backgroundColor : textColor.opacity(0.6))
                }
                .frame(width: 42, height: 42)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(textColor)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(textColor.opacity(0.6))
                }
                
                Spacer(minLength: 8)
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? textColor : textColor.opacity(0.3))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(textColor.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(isSelected ? textColor : hairlineColor.opacity(0.0), lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

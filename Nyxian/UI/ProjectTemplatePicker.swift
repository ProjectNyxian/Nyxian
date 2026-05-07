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

struct ProjectTemplatePickerOption: Identifiable, Equatable {
    let id: String
    let title: String
}

struct ProjectTemplatePickerRow: View {
    let title: String
    let options: [ProjectTemplatePickerOption]
    var disabledIDs: Set<String> = []
    @Binding var selectionID: String
    
    private var selectedTitle: String {
        options.first { $0.id == selectionID }?.title ?? selectionID
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
            
            Spacer(minLength: 12)
            
            Menu {
                ForEach(options) { option in
                    Button {
                        selectionID = option.id
                    } label: {
                        if option.id == selectionID {
                            Label(option.title, systemImage: "checkmark")
                        } else {
                            Text(option.title)
                        }
                    }
                    .disabled(disabledIDs.contains(option.id))
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedTitle)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentTransition(.opacity)
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .frame(width: 140)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color(currentTheme!.textColor).opacity(0.05), in: .rect(cornerRadius: 10, style: .continuous))
            }
            .animation(.snappy, value: selectionID)
            .accessibilityLabel(Text(title.trimmingCharacters(in: CharacterSet(charactersIn: ":"))))
        }
    }
}

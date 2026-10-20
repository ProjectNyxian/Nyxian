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
                .background(Color(LDETheme.currentTheme!.textColor).opacity(0.05), in: .rect(cornerRadius: 10, style: .continuous))
            }
            .animation(.snappy, value: selectionID)
            .accessibilityLabel(Text(title.trimmingCharacters(in: CharacterSet(charactersIn: ":"))))
        }
    }
}

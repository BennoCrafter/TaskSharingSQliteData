import CloudKit
import Dependencies
import SQLiteData
import SwiftUI

struct GroupRow: View {
    let group: UserGroup
    let onShare: () -> Void
    
    @State private var groupToEdit: UserGroup.Draft?

    var body: some View {
        HStack {
            Circle()
                .fill(group.color)
                .frame(width: 12, height: 12)
              
            VStack(alignment: .leading) {
                Text(group.name)
                    .font(.headline)
                if let description = group.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
              
            Spacer()
              
            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
            }
        }
        .contextMenu {
            Button(action: {
                groupToEdit = UserGroup.Draft(group)
            }) {
                Label("Edit", systemImage: "pencil")
            }
        }
        .sheet(item: $groupToEdit) { groupToEdit in
            GroupEditorView(userGroup: groupToEdit)
        }
    }
}

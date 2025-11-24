import CloudKit
import Dependencies
import SQLiteData
import SwiftUI

struct AddGroupView: View {
    @Environment(\.dismiss) var dismiss
    @Dependency(\.defaultDatabase) var database
      
    @State private var name = ""
    @State private var description = ""
    @State private var color = UserGroup.defaultColor
      
    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Description", text: $description)
                ColorPicker("Color", selection: $color)
            }
            .navigationTitle("New Group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await addGroup()
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
      
    private func addGroup() async {
        do {
            try await database.write { db in
                try UserGroup.upsert {
                    UserGroup.Draft(
                        name: name,
                        description: description.isEmpty ? nil : description,
                        color: color
                    )
                }
                .execute(db)
            }
            dismiss()
        } catch {
            print("Failed to add group: \(error)")
        }
    }
}

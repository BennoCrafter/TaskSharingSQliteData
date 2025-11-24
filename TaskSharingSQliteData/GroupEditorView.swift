import CloudKit
import Dependencies
import SQLiteData
import SwiftUI

struct GroupEditorView: View {
    @Environment(\.dismiss) var dismiss
    @Dependency(\.defaultDatabase) var database

    @State private var userGroup: UserGroup.Draft

    @FocusState private var nameFocused: Bool

    init(userGroup: UserGroup.Draft) {
        self._userGroup = State(initialValue: userGroup)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $userGroup.name)
                    .focused($nameFocused)
                TextField("Description", text: Binding(
                    get: { userGroup.description ?? "" },
                    set: { userGroup.description = $0.isEmpty ? nil : $0 }
                ))
                ColorPicker("Color", selection: $userGroup.color)
            }
            .navigationTitle("Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveGroup()
                        }
                    }
                    .disabled(userGroup.name.isEmpty)
                }
            }
            .onAppear {
                nameFocused = true
            }
        }
    }

    private func saveGroup() async {
        do {
            try await database.write { db in
                try UserGroup.upsert { userGroup }.execute(db)
            }
            dismiss()
        } catch {
            print("Failed to add group: \(error)")
        }
    }
}

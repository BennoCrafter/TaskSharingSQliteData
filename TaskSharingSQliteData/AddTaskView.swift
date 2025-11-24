import CloudKit
import Dependencies
import SQLiteData
import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) var dismiss
    @Dependency(\.defaultDatabase) var database
      
    let groups: [UserGroup]
      
    @State private var title = ""
    @State private var content = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600)
    @State private var selectedGroupId: UUID?
      
    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Content", text: $content, axis: .vertical)
                    .lineLimit(3 ... 6)
                  
                DatePicker("Start", selection: $startDate)
                DatePicker("End", selection: $endDate)
                  
                Picker("Group", selection: $selectedGroupId) {
                    Text("None").tag(nil as UUID?)
                    ForEach(groups) { group in
                        HStack {
                            Circle()
                                .fill(group.color)
                                .frame(width: 12, height: 12)
                            Text(group.name)
                        }
                        .tag(group.id as UUID?)
                    }
                }
            }
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await addTask()
                        }
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
      
    private func addTask() async {
        do {
            try await database.write { db in
                try TaskModel.upsert {
                    TaskModel.Draft(
                        title: title,
                        startDate: startDate,
                        endDate: endDate,
                        content: content,
                        userGroupId: selectedGroupId
                    )
                }
                .execute(db)
            }
            dismiss()
        } catch {
            print("Failed to add task: \(error)")
        }
    }
}

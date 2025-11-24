import CloudKit
import Dependencies
import SQLiteData
import SwiftUI

struct TaskEditorView: View {
    @Environment(\.dismiss) var dismiss
    @Dependency(\.defaultDatabase) var database
      
    @FetchAll var groups: [UserGroup]
    
    @State private var task: TaskModel.Draft
    
    init(task: TaskModel.Draft) {
        self._task = State(initialValue: task)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $task.title)
                TextField("Content", text: $task.content, axis: .vertical)
                    .lineLimit(3 ... 6)
                  
                DatePicker("Start", selection: $task.startDate)
                DatePicker("End", selection: $task.endDate)
                  
                Picker("Group", selection: $task.userGroupId) {
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
                    Button("Save") {
                        Task {
                            await saveTask()
                        }
                    }
                    .disabled(task.title.isEmpty)
                }
            }
        }
    }
      
    private func saveTask() async {
        do {
            try await database.write { db in
                try TaskModel.upsert { task }.execute(db)
            }
            dismiss()
        } catch {
            print("Failed to add task: \(error)")
        }
    }
}

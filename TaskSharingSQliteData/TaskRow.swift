import CloudKit
import Dependencies
import SQLiteData
import SwiftUI
 
struct TaskRow: View {
    @Dependency(\.defaultDatabase) var database
      
    let task: TaskModel
    let groups: [UserGroup]
      
    @FetchOne var privateTask: PrivateTaskModel?
      
    var taskGroup: UserGroup? {
        groups.first { $0.id == task.userGroupId }
    }
      
    var isCompleted: Bool {
        privateTask?.completionDate != nil
    }
    
    @State private var taskToEdit: TaskModel.Draft?
      
    var body: some View {
        HStack {
            Button {
                Task {
                    await toggleCompletion()
                }
            } label: {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
              
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                    .strikethrough(isCompleted)
                
                Text(privateTask == nil ? "no private task entry" : "private task entry exists")
                  
                if let group = taskGroup {
                    HStack {
                        Circle()
                            .fill(group.color)
                            .frame(width: 8, height: 8)
                        Text(group.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                  
                Text(task.startDate, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .contextMenu {
                Button(action: {
                    taskToEdit = TaskModel.Draft(task)
                }) {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
        .task {
            await loadPrivateTask()
        }
        .sheet(item: $taskToEdit) { taskToEdit in
            TaskEditorView(task: taskToEdit)
        }
    }
      
    private func loadPrivateTask() async {
        await withErrorReporting {
            try await $privateTask.load(
                PrivateTaskModel.where { $0.taskId.eq(task.id) }
            )
        }
    }
      
    private func toggleCompletion() async {
        do {
            try await database.write { db in
                
                if isCompleted {
                    // Mark as incomplete
                    try PrivateTaskModel.upsert {
                        PrivateTaskModel.Draft(
                            taskId: task.id,
                            completionDate: nil
                        )
                    }
                    .execute(db)
                } else {
                    // Mark as complete
                    try PrivateTaskModel.upsert {
                        PrivateTaskModel.Draft(
                            taskId: task.id,
                            completionDate: Date()
                        )
                    }
                    .execute(db)
                }
            }
            await loadPrivateTask()
        } catch {
            print("Failed to toggle completion: \(error)")
        }
    }
}

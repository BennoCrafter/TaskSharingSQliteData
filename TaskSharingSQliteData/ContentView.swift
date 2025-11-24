import CloudKit
import Dependencies
import SQLiteData
import SwiftUI
  
struct ContentView: View {
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.defaultSyncEngine) var syncEngine
      
    @FetchAll var userGroups: [UserGroup]
    @FetchAll(TaskModel.order(by: \.startDate)) var tasks

    @State private var showingAddGroup = false
    @State private var showingAddTask = false
    @State private var selectedGroup: UserGroup?
    @State private var sharedRecord: SharedRecord?
      
    var body: some View {
        NavigationStack {
            List {
                Section("User Groups") {
                    ForEach(userGroups) { group in
                        GroupRow(group: group) {
                            selectedGroup = group
                            Task {
                                await shareGroup(group)
                            }
                        }
                    }
                }
                  
                Section("Tasks") {
                    ForEach(tasks) { task in
                        TaskRow(task: task, groups: userGroups)
                    }
                }
            }
            .navigationTitle("Task Sharing")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Add Group") { showingAddGroup = true }
                        Button("Add Task") { showingAddTask = true }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddGroup) {
                AddGroupView()
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView(groups: userGroups)
            }
            .sheet(item: $sharedRecord) { sharedRecord in
                CloudSharingView(sharedRecord: sharedRecord)
            }
        }
    }
      
    private func shareGroup(_ group: UserGroup) async {
        do {
            await withErrorReporting {
                sharedRecord = try await syncEngine.share(record: group) { share in
                    share[CKShare.SystemFieldKey.title] = String(localized: "Join '\(group.name)'!")
                }
            }
        } catch {
            print("Failed to share group: \(error)")
        }
    }
}
  
struct GroupRow: View {
    let group: UserGroup
    let onShare: () -> Void
      
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
    }
}
  
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
        }
        .task {
            await loadPrivateTask()
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
                            completionDate: nil,
                            eventId: privateTask?.eventId
                        )
                    }
                    .execute(db)
                } else {
                    // Mark as complete
                    try PrivateTaskModel.upsert {
                        PrivateTaskModel.Draft(
                            taskId: task.id,
                            completionDate: Date(),
                            eventId: privateTask?.eventId
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

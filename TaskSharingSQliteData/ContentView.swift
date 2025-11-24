import CloudKit
import Dependencies
import SQLiteData
import SwiftUI
  
struct ContentView: View {
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.defaultSyncEngine) var syncEngine
      
    @FetchAll var userGroups: [UserGroup]
    @FetchAll(TaskModel.order(by: \.startDate)) var tasks

    @State private var groupDraft: UserGroup.Draft?
    @State private var taskDraft: TaskModel.Draft?

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
                        Button(action: {
                            groupDraft = UserGroup.Draft()
                        }) {
                            Label("Add Group", systemImage: "person.3.fill")
                        }
                        Button(action: {
                            taskDraft = TaskModel.Draft()
                        }) {
                            Label("Add Task", systemImage: "largecircle.fill.circle")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $sharedRecord) { sharedRecord in
                CloudSharingView(sharedRecord: sharedRecord)
            }
            .sheet(item: $groupDraft) { groupDraft in
                GroupEditorView(userGroup: groupDraft)
            }
            .sheet(item: $taskDraft) { taskDraft in
                TaskEditorView(task: taskDraft)
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
  

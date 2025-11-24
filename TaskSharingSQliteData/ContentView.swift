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
                TaskEditorView(task: TaskModel.Draft())
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
  

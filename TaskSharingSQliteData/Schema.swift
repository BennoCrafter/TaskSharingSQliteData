import Dependencies
import CloudKit
import Foundation
import IssueReporting
import OSLog
import SQLiteData
import SwiftUI
import Synchronization

@Table
public struct UserGroup: Identifiable, Sendable {
    public var id: UUID = .init()
    public var name: String = ""
    public var description: String? = nil
    @Column(as: Color.HexRepresentation.self)
    public var color: Color = Self.defaultColor

    public static var defaultColor: Color { Color(red: 0x4a / 255, green: 0x99 / 255, blue: 0xef / 255) }
}

extension UserGroup.Draft: Identifiable {}

@Table("privateTasks")
public struct PrivateTaskModel: Codable, Sendable {
    @Column(primaryKey: true)
    public let taskId: TaskModel.ID
    public var completionDate: Date? = nil
}

extension PrivateTaskModel.Draft {}

@Table("tasks")
public struct TaskModel: Identifiable, Codable, Sendable {
    public var id: UUID = .init()
    public var title: String = ""
    public var startDate: Date = .init()
    public var endDate: Date = .init()
    public var content: String = ""
    public var userGroupId: UserGroup.ID?
}

public nonisolated extension TaskModel.TableColumns {
    nonisolated var idCompare: some QueryExpression<String> {
        #sql("lower(cast(\(self.id) as text))")
    }
}


extension TaskModel.Draft: Identifiable {}

extension DependencyValues {
    mutating func bootstrapDatabase() throws {
        defaultDatabase = try appDatabase()
        defaultSyncEngine = try SyncEngine(
            for: defaultDatabase,
            tables: UserGroup.self, TaskModel.self,
            privateTables: PrivateTaskModel.self
        )
    }
}

func appDatabase() throws -> any DatabaseWriter {
    @Dependency(\.context) var context
    var configuration = Configuration()
    configuration.foreignKeysEnabled = true

    configuration.prepareDatabase { db in
        try db.attachMetadatabase()
        db.add(function: $didInsertMetadata)
    }
    let database = try SQLiteData.defaultDatabase(configuration: configuration)
    logger.debug(
        """
        App database:
        open "\(database.path)"
        """
    )
    var migrator = DatabaseMigrator()
    #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
    #endif

    migrator.registerMigration("Create inital tables") { db in
        let defaultColor = Color.HexRepresentation(queryOutput: UserGroup.defaultColor).hexValue

        // MARK: - UserGroup

        try #sql(
            """
            CREATE TABLE "userGroups" (
              "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
              "name" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT 'UNKNOWN',
              "description" TEXT,
              "color" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT \(raw: defaultColor ?? 0)
            ) STRICT
            """
        ).execute(db)

        // MARK: - Tasks

        try #sql(
            """
            CREATE TABLE "tasks" (
              "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
              "title" TEXT,
              "startDate" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT (date('1970-01-01')),
              "endDate" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT (date('9999-12-31')),
              "content" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
              "userGroupId" TEXT REFERENCES "userGroups"("id") ON DELETE SET NULL
            ) STRICT
            """
        ).execute(db)

        // MARK: - PrivateTasks

        try #sql(
            """
            CREATE TABLE "privateTasks" (
              "taskId" TEXT PRIMARY KEY REFERENCES "tasks"("id") ON DELETE CASCADE,
              "completionDate" TEXT
            ) STRICT
            """
        ).execute(db)
    }

    try migrator.migrate(database)

    try database.write { db in
        try SyncMetadata.createTemporaryTrigger(
            after: .insert { new in
                Values($didInsertMetadata(new.recordType, new.recordName, new.recordPrimaryKey, new.lastKnownServerRecord, new.parentRecordType))
            }
        )
        .execute(db)
    }

    return database
}

@DatabaseFunction(
    as: ((String, String, String, CKRecord.SystemFieldsRepresentation?, String?) -> Void).self
)
func didInsertMetadata(_ recordType: String, _ recordName: String, _ recordPrimaryKey: String, _ lastKnownServerRecord: CKRecord?, _ parentRecordType: String?) {
    @Dependency(\.defaultDatabase) var database
    guard recordType == "tasks" else { return }
    guard parentRecordType == "userGroups" else { return }
    print("New shared task got synced")
    
    Task {
        await withErrorReporting {
            let ta = try await database.read { db in
                try TaskModel
                    .where { $0.idCompare == recordPrimaryKey }
                    .fetchOne(db)
            }
            
            print(ta) // will be nil
            
            let tasks = try await database.read { db in
                try TaskModel.fetchAll(db)
            }
            print(tasks) // will not contain newly synced task
            
            if let ta = ta {
                try await database.write { db in
                    try PrivateTaskModel.upsert { PrivateTaskModel.Draft(taskId: ta.id) }
                        .execute(db)
                }
            }
        }
    }
}

private nonisolated let logger = Logger(subsystem: "TaskSharingSample", category: "Database")

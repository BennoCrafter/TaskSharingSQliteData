import Foundation
import SQLiteData

public struct TaskWithPrivateData {
    public var task: TaskModel.Draft
    public var privateTask: PrivateTaskModel.Draft

    public init(task: TaskModel.Draft, privateTask: PrivateTaskModel.Draft) {
        self.task = task
        self.privateTask = privateTask
    }

    public var isCompleted: Bool {
        self.privateTask.completionDate != nil
    }

    public var completionDate: Date? {
        self.privateTask.completionDate
    }

    public var startDate: Date {
        self.task.startDate
    }

    public var endDate: Date {
        self.task.endDate
    }

    public var title: String {
        self.task.title
    }

    public var content: String {
        self.task.content
    }
}

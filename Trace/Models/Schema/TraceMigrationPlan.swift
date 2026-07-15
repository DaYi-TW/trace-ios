import SwiftData

enum TraceMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [TraceSchemaV1.self, TraceSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(
                fromVersion: TraceSchemaV1.self,
                toVersion: TraceSchemaV2.self
            )
        ]
    }
}

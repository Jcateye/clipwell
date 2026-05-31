import Foundation

enum ClipPipelineFailurePolicy: Sendable {
    case stopOnFailure
    case continueOnFailure
}

actor ClipPipelineRunner {
    private let plugins: [any ClipPipelinePlugin]
    private let failurePolicy: ClipPipelineFailurePolicy

    init(plugins: [any ClipPipelinePlugin], failurePolicy: ClipPipelineFailurePolicy = .continueOnFailure) {
        self.plugins = plugins
        self.failurePolicy = failurePolicy
    }

    func run(_ context: ClipPipelineContext) async throws -> ClipPipelineContext {
        var currentContext = context

        for plugin in plugins {
            let startedAt = Date()
            guard await plugin.canProcess(currentContext) else {
                currentContext.stageResults.append(ClipPipelineStageResult(
                    pluginID: plugin.id,
                    status: .skipped,
                    startedAt: startedAt,
                    endedAt: Date(),
                    message: nil
                ))
                continue
            }

            do {
                currentContext = try await plugin.process(currentContext)
                currentContext.stageResults.append(ClipPipelineStageResult(
                    pluginID: plugin.id,
                    status: .succeeded,
                    startedAt: startedAt,
                    endedAt: Date(),
                    message: nil
                ))
            } catch {
                currentContext.stageResults.append(ClipPipelineStageResult(
                    pluginID: plugin.id,
                    status: .failed,
                    startedAt: startedAt,
                    endedAt: Date(),
                    message: error.localizedDescription
                ))

                if case .stopOnFailure = failurePolicy {
                    throw error
                }
            }
        }

        return currentContext
    }
}

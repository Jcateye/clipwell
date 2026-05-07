import Foundation

actor ProActionEngine {
    private let actions: [ProActionKind: ProAction]

    init(actions: [any ProAction]) {
        var map: [ProActionKind: ProAction] = [:]
        for action in actions {
            map[action.kind] = action
        }
        self.actions = map
    }

    func run(_ kinds: [ProActionKind], context: ProActionContext) async throws -> ProActionResult {
        var currentContext = context
        var lastResult = ProActionResult()

        for kind in kinds {
            guard let action = actions[kind] else { continue }
            let result = try await action.run(currentContext)
            lastResult = result

            if let text = result.text {
                currentContext.inputText = text
            }
            if let imageData = result.imageData {
                currentContext.inputImageData = imageData
            }
        }

        return lastResult
    }
}

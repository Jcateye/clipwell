import Foundation

struct ProActionContext {
    var trigger: ProTriggerKind
    var clipboardItem: ClipItem?
    var inputText: String?
    var inputImageData: Data?
    var sourceAppName: String?
    var userPrompt: String?
}

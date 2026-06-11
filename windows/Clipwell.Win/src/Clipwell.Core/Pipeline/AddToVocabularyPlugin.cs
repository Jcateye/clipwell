using Clipwell.Core.Vocabulary;

namespace Clipwell.Core.Pipeline;

/// <summary>Saves short text clips into the vocabulary store (mac: AddToVocabularyAction).</summary>
public sealed class AddToVocabularyPlugin : IClipPipelinePlugin
{
    /// <summary>Auto-capture only saves short snippets; longer text is prose, not vocabulary.</summary>
    private const int MaxAutoCaptureLength = 80;

    private readonly VocabularyStore _store;

    public AddToVocabularyPlugin(VocabularyStore store) => _store = store;

    public string Id => BuiltInPluginIds.AddToVocabulary;
    public string Name => "Add to Vocabulary";

    public Task<bool> CanProcessAsync(ClipPipelineContext context)
    {
        var text = context.CurrentText?.Trim();
        var eligible = !string.IsNullOrEmpty(text) &&
            (context.Trigger == ClipPipelineTrigger.Manual || text.Length <= MaxAutoCaptureLength);
        return Task.FromResult(eligible);
    }

    public Task ProcessAsync(ClipPipelineContext context, CancellationToken cancellationToken)
    {
        _store.Add(context.CurrentText!, context.OriginalClip.SourceApp, context.OriginalClip.Id);
        return Task.CompletedTask;
    }
}

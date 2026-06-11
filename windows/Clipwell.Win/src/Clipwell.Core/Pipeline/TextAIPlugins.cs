using Clipwell.Core.AI;

namespace Clipwell.Core.Pipeline;

/// <summary>
/// Shared base for plugins that transform the context's current text via the AI service
/// and emit the result as an artifact (saved as a proDerived clip by the pipeline host).
/// </summary>
public abstract class TextAIPluginBase : IClipPipelinePlugin
{
    protected readonly ITextAIService AI;

    protected TextAIPluginBase(ITextAIService ai) => AI = ai;

    public abstract string Id { get; }
    public abstract string Name { get; }
    protected abstract string ArtifactKind { get; }

    public Task<bool> CanProcessAsync(ClipPipelineContext context) =>
        Task.FromResult(!string.IsNullOrWhiteSpace(context.CurrentText));

    public async Task ProcessAsync(ClipPipelineContext context, CancellationToken cancellationToken)
    {
        var result = await TransformAsync(context.CurrentText!, cancellationToken).ConfigureAwait(false);
        context.Artifacts.Add(new ClipPipelineArtifact(ArtifactKind, Name, result, Id));
        context.RequestedEffects |= ClipPipelineEffects.SaveDerivedClip;
    }

    protected abstract Task<string> TransformAsync(string text, CancellationToken cancellationToken);
}

public sealed class TranslatePlugin : TextAIPluginBase
{
    private readonly Func<string> _targetLanguageProvider;

    public TranslatePlugin(ITextAIService ai, Func<string> targetLanguageProvider) : base(ai) =>
        _targetLanguageProvider = targetLanguageProvider;

    public override string Id => BuiltInPluginIds.Translate;
    public override string Name => "Translate";
    protected override string ArtifactKind => "translation";

    protected override Task<string> TransformAsync(string text, CancellationToken cancellationToken) =>
        AI.TranslateAsync(text, _targetLanguageProvider(), cancellationToken);
}

public sealed class SummarizePlugin : TextAIPluginBase
{
    public SummarizePlugin(ITextAIService ai) : base(ai)
    {
    }

    public override string Id => BuiltInPluginIds.Summarize;
    public override string Name => "Summarize";
    protected override string ArtifactKind => "summary";

    protected override Task<string> TransformAsync(string text, CancellationToken cancellationToken) =>
        AI.SummarizeAsync(text, cancellationToken);
}

public sealed class RewritePlugin : TextAIPluginBase
{
    public RewritePlugin(ITextAIService ai) : base(ai)
    {
    }

    public override string Id => BuiltInPluginIds.Rewrite;
    public override string Name => "Rewrite";
    protected override string ArtifactKind => "rewrite";

    protected override Task<string> TransformAsync(string text, CancellationToken cancellationToken) =>
        AI.RewriteAsync(text, cancellationToken);
}

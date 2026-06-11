using Clipwell.Core.Data;
using Clipwell.Core.Models;
using Clipwell.Core.Services;

namespace Clipwell.Core.Pipeline;

/// <summary>
/// Orchestrates pipeline runs against the clip store: picks enabled plugins
/// (post-capture order comes from settings), runs them, and persists each emitted
/// artifact as a proDerived clip linked to the original.
/// </summary>
public sealed class PipelineHost
{
    private readonly ClipRepository _repository;
    private readonly IReadOnlyDictionary<string, IClipPipelinePlugin> _pluginsById;

    public event EventHandler<ClipItem>? DerivedClipSaved;
    public event EventHandler<ClipPipelineStageResult>? StageFailed;

    public PipelineHost(ClipRepository repository, IEnumerable<IClipPipelinePlugin> plugins)
    {
        _repository = repository;
        _pluginsById = plugins.ToDictionary(plugin => plugin.Id);
    }

    /// <summary>Runs the user-configured post-capture stages over a freshly captured clip.</summary>
    public Task<ClipPipelineContext> RunPostCaptureAsync(
        ClipItem clip,
        IEnumerable<ClipPipelineStageConfiguration> stages,
        CancellationToken cancellationToken = default)
    {
        var plugins = stages
            .Where(stage => stage.Enabled)
            .OrderBy(stage => stage.Order)
            .Select(stage => _pluginsById.GetValueOrDefault(stage.PluginId))
            .Where(plugin => plugin is not null)
            .Select(plugin => plugin!)
            .ToList();
        return RunAsync(new ClipPipelineContext(ClipPipelineTrigger.PostCapture, clip), plugins, cancellationToken);
    }

    /// <summary>Runs a single plugin on demand (drawer context-menu actions).</summary>
    public Task<ClipPipelineContext> RunManualAsync(
        ClipItem clip,
        string pluginId,
        CancellationToken cancellationToken = default)
    {
        var plugins = _pluginsById.TryGetValue(pluginId, out var plugin)
            ? new List<IClipPipelinePlugin> { plugin }
            : [];
        return RunAsync(new ClipPipelineContext(ClipPipelineTrigger.Manual, clip), plugins, cancellationToken);
    }

    private async Task<ClipPipelineContext> RunAsync(
        ClipPipelineContext context,
        IReadOnlyList<IClipPipelinePlugin> plugins,
        CancellationToken cancellationToken)
    {
        var runner = new ClipPipelineRunner(plugins);
        var result = await runner.RunAsync(context, cancellationToken).ConfigureAwait(false);

        foreach (var failure in result.StageResults.Where(stage => stage.Status == ClipPipelineStageStatus.Failed))
        {
            StageFailed?.Invoke(this, failure);
        }

        if (result.RequestedEffects.HasFlag(ClipPipelineEffects.SaveDerivedClip))
        {
            foreach (var artifact in result.Artifacts)
            {
                var derived = ClipItem.CreateNew(
                    ClipType.Text,
                    artifact.Text,
                    payloadPath: null,
                    sourceApp: result.OriginalClip.SourceApp,
                    contentHash: ContentHasher.Hash(artifact.Text),
                    origin: ClipOrigin.ProDerived,
                    derivedFromClipId: result.OriginalClip.Id);
                _repository.Insert(derived);
                DerivedClipSaved?.Invoke(this, derived);
            }
        }
        return result;
    }
}

namespace Clipwell.Core.Pipeline;

public enum ClipPipelineFailurePolicy
{
    StopOnFailure,
    ContinueOnFailure,
}

/// <summary>
/// Runs plugins sequentially over a context, recording a stage result per plugin.
/// Mirrors the macOS ClipPipelineRunner: failures are recorded and, by default,
/// do not abort the remaining stages.
/// </summary>
public sealed class ClipPipelineRunner
{
    private readonly IReadOnlyList<IClipPipelinePlugin> _plugins;
    private readonly ClipPipelineFailurePolicy _failurePolicy;

    public ClipPipelineRunner(
        IReadOnlyList<IClipPipelinePlugin> plugins,
        ClipPipelineFailurePolicy failurePolicy = ClipPipelineFailurePolicy.ContinueOnFailure)
    {
        _plugins = plugins;
        _failurePolicy = failurePolicy;
    }

    public async Task<ClipPipelineContext> RunAsync(
        ClipPipelineContext context,
        CancellationToken cancellationToken = default)
    {
        foreach (var plugin in _plugins)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var startedAt = DateTimeOffset.UtcNow;

            if (!await plugin.CanProcessAsync(context).ConfigureAwait(false))
            {
                context.StageResults.Add(new ClipPipelineStageResult(
                    plugin.Id, ClipPipelineStageStatus.Skipped, startedAt, DateTimeOffset.UtcNow, null));
                continue;
            }

            try
            {
                await plugin.ProcessAsync(context, cancellationToken).ConfigureAwait(false);
                context.StageResults.Add(new ClipPipelineStageResult(
                    plugin.Id, ClipPipelineStageStatus.Succeeded, startedAt, DateTimeOffset.UtcNow, null));
            }
            catch (OperationCanceledException)
            {
                throw;
            }
            catch (Exception ex)
            {
                context.StageResults.Add(new ClipPipelineStageResult(
                    plugin.Id, ClipPipelineStageStatus.Failed, startedAt, DateTimeOffset.UtcNow, ex.Message));
                if (_failurePolicy == ClipPipelineFailurePolicy.StopOnFailure)
                {
                    throw;
                }
            }
        }
        return context;
    }
}

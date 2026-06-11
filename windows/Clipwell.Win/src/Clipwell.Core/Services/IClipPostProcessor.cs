using Clipwell.Core.Models;

namespace Clipwell.Core.Services;

/// <summary>
/// Seam for the future plugin pipeline (mac: Pipeline/ClipPipeline.swift).
/// Post-MVP features (OCR, translate, summarize) hook in here as processors
/// that may return a derived clip (origin=proDerived) for a captured clip.
/// </summary>
public interface IClipPostProcessor
{
    Task<ClipItem?> ProcessAsync(ClipItem clip, CancellationToken cancellationToken = default);
}

public sealed class NoOpClipPostProcessor : IClipPostProcessor
{
    public Task<ClipItem?> ProcessAsync(ClipItem clip, CancellationToken cancellationToken = default) =>
        Task.FromResult<ClipItem?>(null);
}

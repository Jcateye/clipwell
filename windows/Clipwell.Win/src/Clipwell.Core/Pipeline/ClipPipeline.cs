using Clipwell.Core.Models;

namespace Clipwell.Core.Pipeline;

/// <summary>
/// Plugin pipeline model, ported from the macOS app (Pipeline/ClipPipeline.swift).
/// A pipeline run threads a context through an ordered list of plugins; each plugin
/// may transform the current content, emit artifacts (derived clips), and request effects.
/// </summary>
public enum ClipPipelineTrigger
{
    PostCapture,
    Manual,
    Scheduled,
}

public enum ClipPipelineStageStatus
{
    Skipped,
    Succeeded,
    Failed,
}

public sealed record ClipPipelineStageResult(
    string PluginId,
    ClipPipelineStageStatus Status,
    DateTimeOffset StartedAt,
    DateTimeOffset EndedAt,
    string? Message);

[Flags]
public enum ClipPipelineEffects
{
    None = 0,
    SaveDerivedClip = 1 << 0,
    CopyToClipboard = 1 << 1,
    PasteImmediately = 1 << 2,
    ShowBanner = 1 << 3,
}

/// <summary>A derived output of a plugin (e.g. OCR text, a translation) tied to the producing plugin.</summary>
public sealed record ClipPipelineArtifact(
    string Kind,
    string Title,
    string Text,
    string ProducerPluginId,
    IReadOnlyDictionary<string, string>? Metadata = null);

public sealed class ClipPipelineContext
{
    public Guid RunId { get; } = Guid.NewGuid();
    public ClipPipelineTrigger Trigger { get; }
    public ClipItem OriginalClip { get; }

    /// <summary>Working text content, updated as plugins transform it. Null for image clips until OCR runs.</summary>
    public string? CurrentText { get; set; }

    public Dictionary<string, string> Metadata { get; } = [];
    public List<ClipPipelineArtifact> Artifacts { get; } = [];
    public List<ClipPipelineStageResult> StageResults { get; } = [];
    public ClipPipelineEffects RequestedEffects { get; set; } = ClipPipelineEffects.None;

    public ClipPipelineContext(ClipPipelineTrigger trigger, ClipItem originalClip)
    {
        Trigger = trigger;
        OriginalClip = originalClip;
        CurrentText = originalClip.PlainText;
    }
}

public interface IClipPipelinePlugin
{
    string Id { get; }
    string Name { get; }

    Task<bool> CanProcessAsync(ClipPipelineContext context);
    Task ProcessAsync(ClipPipelineContext context, CancellationToken cancellationToken);
}

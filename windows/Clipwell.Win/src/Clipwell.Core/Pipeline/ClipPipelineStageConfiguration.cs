namespace Clipwell.Core.Pipeline;

/// <summary>
/// User-configurable post-capture pipeline stage: which plugin runs, in what order,
/// and whether it is enabled. Persisted in settings.json (mac: post_capture_pipeline_stages).
/// </summary>
public sealed class ClipPipelineStageConfiguration
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string PluginId { get; set; } = "";
    public bool Enabled { get; set; }
    public int Order { get; set; }
}

public static class BuiltInPluginIds
{
    public const string ImageOcr = "builtin.image-ocr";
    public const string Translate = "builtin.translate";
    public const string Summarize = "builtin.summarize";
    public const string Rewrite = "builtin.rewrite";
    public const string AddToVocabulary = "builtin.add-to-vocabulary";

    /// <summary>Default post-capture stages: OCR first (disabled until the user opts in), nothing else automatic.</summary>
    public static List<ClipPipelineStageConfiguration> DefaultPostCaptureStages() =>
    [
        new() { PluginId = ImageOcr, Enabled = false, Order = 10 },
        new() { PluginId = Translate, Enabled = false, Order = 20 },
        new() { PluginId = AddToVocabulary, Enabled = false, Order = 30 },
    ];
}

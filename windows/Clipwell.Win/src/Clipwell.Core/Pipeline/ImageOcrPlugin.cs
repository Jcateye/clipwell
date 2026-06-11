using Clipwell.Core.Models;

namespace Clipwell.Core.Pipeline;

/// <summary>Platform OCR seam; implemented on Windows with Windows.Media.Ocr.</summary>
public interface IOcrService
{
    Task<string> RecognizeAsync(string imagePath, CancellationToken cancellationToken = default);
}

/// <summary>
/// Extracts text from image clips (mac: Pro/OCR/ImageOCRAction). The recognized text
/// becomes the context's working text — so downstream plugins (translate, vocabulary)
/// can chain off an image — and an artifact saved as a derived clip.
/// </summary>
public sealed class ImageOcrPlugin : IClipPipelinePlugin
{
    private readonly IOcrService _ocr;

    public ImageOcrPlugin(IOcrService ocr) => _ocr = ocr;

    public string Id => BuiltInPluginIds.ImageOcr;
    public string Name => "Image OCR";

    public Task<bool> CanProcessAsync(ClipPipelineContext context)
    {
        var clip = context.OriginalClip;
        var isRawImage = clip.Type == ClipType.Media && clip.PayloadPath is not null && clip.PlainText is null;
        return Task.FromResult(isRawImage);
    }

    public async Task ProcessAsync(ClipPipelineContext context, CancellationToken cancellationToken)
    {
        var text = await _ocr.RecognizeAsync(context.OriginalClip.PayloadPath!, cancellationToken).ConfigureAwait(false);
        if (string.IsNullOrWhiteSpace(text))
        {
            return;
        }
        context.CurrentText = text;
        context.Artifacts.Add(new ClipPipelineArtifact("ocr-text", Name, text, Id));
        context.RequestedEffects |= ClipPipelineEffects.SaveDerivedClip;
    }
}

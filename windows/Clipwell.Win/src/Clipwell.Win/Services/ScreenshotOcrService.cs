using System.IO;
using Clipwell.Core.Data;
using Clipwell.Core.Models;
using Clipwell.Core.Pipeline;
using Clipwell.Core.Services;
using Clipwell.Win.Views;

namespace Clipwell.Win.Services;

/// <summary>
/// Screenshot OCR flow (mac: ScreenshotOCRAction): user drags a region on a full-screen
/// overlay, the region is captured to a PNG payload clip, then OCR'd into a derived text clip.
/// </summary>
public sealed class ScreenshotOcrService
{
    private readonly ClipRepository _repository;
    private readonly PayloadStore _payloadStore;
    private readonly IOcrService _ocr;

    public event EventHandler<ClipItem>? ClipSaved;

    public ScreenshotOcrService(ClipRepository repository, PayloadStore payloadStore, IOcrService ocr)
    {
        _repository = repository;
        _payloadStore = payloadStore;
        _ocr = ocr;
    }

    public async Task CaptureAndRecognizeAsync()
    {
        var region = RegionSelectionWindow.SelectRegion();
        if (region is not { } rect || rect.Width < 2 || rect.Height < 2)
        {
            return;
        }

        using var bitmap = new System.Drawing.Bitmap((int)rect.Width, (int)rect.Height);
        using (var graphics = System.Drawing.Graphics.FromImage(bitmap))
        {
            graphics.CopyFromScreen((int)rect.X, (int)rect.Y, 0, 0, bitmap.Size);
        }
        using var stream = new MemoryStream();
        bitmap.Save(stream, System.Drawing.Imaging.ImageFormat.Png);
        var pngData = stream.ToArray();

        var imageClip = ClipItem.CreateNew(
            ClipType.Media, plainText: null, payloadPath: null,
            sourceApp: "Clipwell Screenshot", contentHash: ContentHasher.Hash(pngData));
        var payloadPath = _payloadStore.Save(imageClip.Id, "png", pngData);
        imageClip = imageClip with { PayloadPath = payloadPath };
        _repository.Insert(imageClip);
        ClipSaved?.Invoke(this, imageClip);

        var text = await _ocr.RecognizeAsync(payloadPath);
        if (string.IsNullOrWhiteSpace(text))
        {
            return;
        }
        var textClip = ClipItem.CreateNew(
            ClipType.Text, text, payloadPath: null,
            sourceApp: "Clipwell Screenshot", contentHash: ContentHasher.Hash(text),
            origin: ClipOrigin.ProDerived, derivedFromClipId: imageClip.Id);
        _repository.Insert(textClip);
        ClipSaved?.Invoke(this, textClip);
    }
}

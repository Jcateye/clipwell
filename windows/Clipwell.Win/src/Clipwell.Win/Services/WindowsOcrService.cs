using System.IO;
using Clipwell.Core.Pipeline;
using Windows.Globalization;
using Windows.Graphics.Imaging;
using Windows.Media.Ocr;
using Windows.Storage;
using Windows.Storage.Streams;

namespace Clipwell.Win.Services;

/// <summary>
/// OCR via the in-box Windows.Media.Ocr engine (mac counterpart: Vision-based OCRService).
/// Tries the user-configured languages in order, falling back to the user profile languages.
/// </summary>
public sealed class WindowsOcrService : IOcrService
{
    private readonly Func<IReadOnlyList<string>> _languageTagsProvider;

    public WindowsOcrService(Func<IReadOnlyList<string>> languageTagsProvider) =>
        _languageTagsProvider = languageTagsProvider;

    public async Task<string> RecognizeAsync(string imagePath, CancellationToken cancellationToken = default)
    {
        var engine = CreateEngine();
        if (engine is null)
        {
            throw new InvalidOperationException(
                "No OCR language pack is available. Install one under Windows Settings > Time & Language.");
        }

        var file = await StorageFile.GetFileFromPathAsync(Path.GetFullPath(imagePath));
        using IRandomAccessStream stream = await file.OpenAsync(FileAccessMode.Read);
        var decoder = await BitmapDecoder.CreateAsync(stream);
        using var bitmap = await decoder.GetSoftwareBitmapAsync();

        cancellationToken.ThrowIfCancellationRequested();
        var result = await engine.RecognizeAsync(bitmap);
        return string.Join("\n", result.Lines.Select(line => line.Text)).Trim();
    }

    private OcrEngine? CreateEngine()
    {
        foreach (var tag in _languageTagsProvider())
        {
            if (Language.IsWellFormed(tag) && OcrEngine.TryCreateFromLanguage(new Language(tag)) is { } engine)
            {
                return engine;
            }
        }
        return OcrEngine.TryCreateFromUserProfileLanguages();
    }
}

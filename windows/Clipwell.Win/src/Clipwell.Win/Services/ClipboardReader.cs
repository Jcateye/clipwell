using System.IO;
using System.Text;
using System.Windows;
using System.Windows.Media.Imaging;
using Clipwell.Core.Models;
using Clipwell.Core.Services;

namespace Clipwell.Win.Services;

public sealed record ParsedClip(
    ClipType Type,
    string? PlainText,
    byte[]? PayloadData,
    string? PayloadExtension,
    string ContentHash);

/// <summary>
/// Reads the current clipboard into a ParsedClip, mirroring the macOS ClipboardParser
/// format priority: file drop → image → RTF → HTML → plain text.
/// Clipboard access is retried because the copying app may still hold the clipboard open.
/// </summary>
public sealed class ClipboardReader
{
    private const int RetryCount = 3;
    private const int RetryDelayMs = 50;

    private static readonly HashSet<string> AllowedDocumentExtensions =
    [
        "pdf", "doc", "docx", "pages", "rtf", "rtfd", "txt", "md",
        "xls", "xlsx", "numbers", "csv", "ppt", "pptx", "key",
        "jpg", "jpeg", "png", "gif", "heic", "webp", "tiff",
        "mp4", "mov", "m4v", "webm", "avi", "mkv",
    ];

    private static readonly HashSet<string> MediaExtensions =
    [
        "jpg", "jpeg", "png", "gif", "heic", "webp", "tiff",
        "mp4", "mov", "m4v", "webm", "avi", "mkv",
    ];

    public ParsedClip? Read(IReadOnlySet<string> ignoredFileExtensions)
    {
        for (var attempt = 0; attempt < RetryCount; attempt++)
        {
            try
            {
                return ReadOnce(ignoredFileExtensions);
            }
            catch (System.Runtime.InteropServices.ExternalException)
            {
                Thread.Sleep(RetryDelayMs);
            }
        }
        return null;
    }

    private ParsedClip? ReadOnce(IReadOnlySet<string> ignoredFileExtensions)
    {
        if (ParseFileDrop(ignoredFileExtensions) is { } fileClip)
        {
            return fileClip;
        }
        if (ParseImage() is { } imageClip)
        {
            return imageClip;
        }
        if (ParseRichText() is { } richClip)
        {
            return richClip;
        }
        return ParsePlainText();
    }

    private static ParsedClip? ParseFileDrop(IReadOnlySet<string> ignoredFileExtensions)
    {
        if (!Clipboard.ContainsFileDropList())
        {
            return null;
        }
        var files = Clipboard.GetFileDropList();
        if (files.Count == 0 || files[0] is not { } path)
        {
            return null;
        }

        var extension = Path.GetExtension(path).TrimStart('.').ToLowerInvariant();
        if (!AllowedDocumentExtensions.Contains(extension) || ignoredFileExtensions.Contains(extension))
        {
            return null;
        }

        // Hash on path + mtime, matching the mac parser, so re-copying an edited file is a new clip.
        var hashInput = path;
        try
        {
            hashInput += $"|{new FileInfo(path).LastWriteTimeUtc.Ticks}";
        }
        catch (IOException)
        {
        }

        return new ParsedClip(
            MediaExtensions.Contains(extension) ? ClipType.Media : ClipType.Document,
            PlainText: path,
            PayloadData: null,
            PayloadExtension: null,
            ContentHash: ContentHasher.Hash(hashInput));
    }

    private static ParsedClip? ParseImage()
    {
        if (!Clipboard.ContainsImage() || Clipboard.GetImage() is not { } image)
        {
            return null;
        }
        var encoder = new PngBitmapEncoder();
        encoder.Frames.Add(BitmapFrame.Create(image));
        using var stream = new MemoryStream();
        encoder.Save(stream);
        var pngData = stream.ToArray();

        return new ParsedClip(
            ClipType.Media,
            PlainText: null,
            PayloadData: pngData,
            PayloadExtension: "png",
            ContentHash: ContentHasher.Hash(pngData));
    }

    private static ParsedClip? ParseRichText()
    {
        var dataObject = Clipboard.GetDataObject();
        if (dataObject is null)
        {
            return null;
        }

        if (dataObject.GetDataPresent(DataFormats.Rtf) &&
            dataObject.GetData(DataFormats.Rtf) is string rtf && rtf.Length > 0)
        {
            var rtfBytes = Encoding.UTF8.GetBytes(rtf);
            return new ParsedClip(
                ClipType.Rtf,
                PlainText: PlainTextFromClipboard(),
                PayloadData: rtfBytes,
                PayloadExtension: "rtf",
                ContentHash: ContentHasher.Hash(rtfBytes));
        }

        if (dataObject.GetDataPresent(DataFormats.Html) &&
            dataObject.GetData(DataFormats.Html) is string cfHtml && cfHtml.Length > 0)
        {
            var html = ExtractHtmlFragment(cfHtml);
            var htmlBytes = Encoding.UTF8.GetBytes(html);
            return new ParsedClip(
                ClipType.Html,
                PlainText: PlainTextFromClipboard(),
                PayloadData: htmlBytes,
                PayloadExtension: "html",
                ContentHash: ContentHasher.Hash(htmlBytes));
        }

        return null;
    }

    private static ParsedClip? ParsePlainText()
    {
        if (!Clipboard.ContainsText())
        {
            return null;
        }
        var text = Clipboard.GetText();
        if (string.IsNullOrEmpty(text))
        {
            return null;
        }
        return new ParsedClip(
            ClipType.Text,
            PlainText: text,
            PayloadData: null,
            PayloadExtension: null,
            ContentHash: ContentHasher.Hash(text));
    }

    private static string? PlainTextFromClipboard() =>
        Clipboard.ContainsText() ? Clipboard.GetText() : null;

    /// <summary>
    /// CF_HTML payloads carry a header (Version/StartHTML/EndHTML/StartFragment/EndFragment)
    /// before the markup; strip it so the stored payload is plain HTML like on macOS.
    /// </summary>
    internal static string ExtractHtmlFragment(string cfHtml)
    {
        var htmlStart = cfHtml.IndexOf("<html", StringComparison.OrdinalIgnoreCase);
        if (htmlStart < 0)
        {
            htmlStart = cfHtml.IndexOf("<!DOCTYPE", StringComparison.OrdinalIgnoreCase);
        }
        if (htmlStart < 0)
        {
            htmlStart = cfHtml.IndexOf("<", StringComparison.Ordinal);
        }
        return htmlStart >= 0 ? cfHtml[htmlStart..] : cfHtml;
    }
}

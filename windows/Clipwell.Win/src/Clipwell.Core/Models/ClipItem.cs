namespace Clipwell.Core.Models;

/// <summary>
/// Clip content type. Raw values must stay identical to the macOS app
/// (Sources/ClipboardDrawer/Models/ClipItem.swift) so databases stay interchangeable.
/// </summary>
public enum ClipType
{
    Text,
    Rtf,
    Html,
    Media,
    Document,
}

public enum ClipOrigin
{
    Original,
    ProDerived,
}

public enum ClipFilter
{
    All,
    Text,
    Media,
    Document,
}

public static class ClipEnumValues
{
    public static string ToRaw(this ClipType type) => type switch
    {
        ClipType.Text => "text",
        ClipType.Rtf => "rtf",
        ClipType.Html => "html",
        ClipType.Media => "media",
        ClipType.Document => "document",
        _ => throw new ArgumentOutOfRangeException(nameof(type)),
    };

    public static ClipType? ClipTypeFromRaw(string raw) => raw switch
    {
        "text" => ClipType.Text,
        "rtf" => ClipType.Rtf,
        "html" => ClipType.Html,
        "media" => ClipType.Media,
        "document" => ClipType.Document,
        _ => null,
    };

    public static string ToRaw(this ClipOrigin origin) => origin switch
    {
        ClipOrigin.Original => "original",
        ClipOrigin.ProDerived => "proDerived",
        _ => throw new ArgumentOutOfRangeException(nameof(origin)),
    };

    public static ClipOrigin ClipOriginFromRaw(string? raw) =>
        raw == "proDerived" ? ClipOrigin.ProDerived : ClipOrigin.Original;
}

/// <summary>
/// One clipboard history entry. Field-for-field mirror of the macOS ClipItem.
/// </summary>
public sealed record ClipItem(
    string Id,
    DateTimeOffset CreatedAt,
    ClipType Type,
    string? PlainText,
    string? PayloadPath,
    string? SourceApp,
    bool IsPinned,
    string ContentHash,
    ClipOrigin Origin,
    string? DerivedFromClipId)
{
    public static ClipItem CreateNew(
        ClipType type,
        string? plainText,
        string? payloadPath,
        string? sourceApp,
        string contentHash,
        ClipOrigin origin = ClipOrigin.Original,
        string? derivedFromClipId = null) =>
        new(
            Guid.NewGuid().ToString().ToUpperInvariant(),
            DateTimeOffset.UtcNow,
            type,
            plainText,
            payloadPath,
            sourceApp,
            IsPinned: false,
            contentHash,
            origin,
            derivedFromClipId);

    public string Title
    {
        get
        {
            if (Type is ClipType.Media or ClipType.Document && !string.IsNullOrEmpty(PlainText))
            {
                return Path.GetFileName(PlainText.TrimEnd('/', '\\'));
            }
            if (Type == ClipType.Media)
            {
                return "Media clip";
            }
            var value = PlainText?.Trim() ?? string.Empty;
            return value.Length == 0 ? Type.ToRaw() : value;
        }
    }
}

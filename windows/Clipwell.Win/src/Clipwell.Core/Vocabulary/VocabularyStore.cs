using System.Text.Json;
using System.Text.Json.Serialization;

namespace Clipwell.Core.Vocabulary;

/// <summary>One learned vocabulary entry. Field-for-field mirror of the macOS VocabularyItem.</summary>
public sealed record VocabularyItem(
    string Id,
    DateTimeOffset CreatedAt,
    string SourceText,
    string NormalizedText,
    string? SourceApp,
    string? SourceClipId);

/// <summary>
/// JSON-array store at %APPDATA%\Clipwell\vocabulary.json (mac: vocabulary.json under
/// Application Support). Deduplicates on normalized (lowercased, trimmed) text.
/// </summary>
public sealed class VocabularyStore
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
        WriteIndented = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.Never,
    };

    private readonly string _path;
    private List<VocabularyItem> _items;

    public VocabularyStore(string path)
    {
        _path = path;
        _items = LoadFromDisk();
    }

    public IReadOnlyList<VocabularyItem> Items => _items;

    public static string Normalize(string text) => text.Trim().ToLowerInvariant();

    /// <summary>Adds an entry unless an item with the same normalized text already exists. Returns the added item, or null if duplicate/empty.</summary>
    public VocabularyItem? Add(string sourceText, string? sourceApp = null, string? sourceClipId = null)
    {
        var normalized = Normalize(sourceText);
        if (normalized.Length == 0 || _items.Any(item => item.NormalizedText == normalized))
        {
            return null;
        }
        var item = new VocabularyItem(
            Guid.NewGuid().ToString().ToUpperInvariant(),
            DateTimeOffset.UtcNow,
            sourceText.Trim(),
            normalized,
            sourceApp,
            sourceClipId);
        _items.Insert(0, item);
        Save();
        return item;
    }

    public bool Remove(string id)
    {
        var removed = _items.RemoveAll(item => item.Id == id) > 0;
        if (removed)
        {
            Save();
        }
        return removed;
    }

    public IReadOnlyList<VocabularyItem> Search(string query)
    {
        var normalized = Normalize(query);
        return normalized.Length == 0
            ? _items
            : _items.Where(item => item.NormalizedText.Contains(normalized)).ToList();
    }

    private void Save()
    {
        var json = JsonSerializer.Serialize(_items, JsonOptions);
        var tempPath = _path + ".tmp";
        File.WriteAllText(tempPath, json);
        if (File.Exists(_path))
        {
            File.Replace(tempPath, _path, destinationBackupFileName: null);
        }
        else
        {
            File.Move(tempPath, _path);
        }
    }

    private List<VocabularyItem> LoadFromDisk()
    {
        try
        {
            if (File.Exists(_path))
            {
                var json = File.ReadAllText(_path);
                return JsonSerializer.Deserialize<List<VocabularyItem>>(json, JsonOptions) ?? [];
            }
        }
        catch (Exception ex) when (ex is JsonException or IOException)
        {
        }
        return [];
    }
}

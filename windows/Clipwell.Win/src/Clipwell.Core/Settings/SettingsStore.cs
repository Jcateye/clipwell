using System.Text.Json;
using System.Text.Json.Serialization;

namespace Clipwell.Core.Settings;

/// <summary>
/// Loads and saves AppSettings as camelCase JSON with atomic writes.
/// Ignore-list parsing mirrors the macOS SettingsStore.shouldIgnore / ignoredFileExtensions rules.
/// </summary>
public sealed class SettingsStore
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
        WriteIndented = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.Never,
    };

    private readonly string _path;

    public AppSettings Current { get; private set; }

    public event EventHandler? SettingsChanged;

    public SettingsStore(string path)
    {
        _path = path;
        Current = LoadFromDisk();
    }

    public void Save()
    {
        var json = JsonSerializer.Serialize(Current, JsonOptions);
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
        SettingsChanged?.Invoke(this, EventArgs.Empty);
    }

    public void Update(Action<AppSettings> mutate)
    {
        mutate(Current);
        Save();
    }

    /// <summary>App-name match against the ignore list: one rule per line, case-insensitive, exact or substring.</summary>
    public bool ShouldIgnoreApp(string? appName)
    {
        if (string.IsNullOrEmpty(appName))
        {
            return false;
        }
        var rules = Current.IgnoredAppListText
            .Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(rule => rule.ToLowerInvariant())
            .Where(rule => rule.Length > 0)
            .ToList();
        if (rules.Count == 0)
        {
            return false;
        }
        var candidate = appName.ToLowerInvariant();
        return rules.Any(rule => candidate == rule || candidate.Contains(rule));
    }

    public IReadOnlySet<string> IgnoredFileExtensions =>
        Current.IgnoredFileExtensionsText
            .Split(['\n', '\r', ',', ';', ' ', '\t'], StringSplitOptions.RemoveEmptyEntries)
            .Select(ext => ext.Trim().TrimStart('.').ToLowerInvariant())
            .Where(ext => ext.Length > 0)
            .ToHashSet();

    private AppSettings LoadFromDisk()
    {
        try
        {
            if (File.Exists(_path))
            {
                var json = File.ReadAllText(_path);
                if (JsonSerializer.Deserialize<AppSettings>(json, JsonOptions) is { } settings)
                {
                    return settings;
                }
            }
        }
        catch (Exception ex) when (ex is JsonException or IOException)
        {
            // Corrupt or unreadable settings: fall back to defaults and rewrite on next save.
        }
        return new AppSettings();
    }
}

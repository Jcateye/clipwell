namespace Clipwell.Core.Data;

/// <summary>
/// Resolves the application data layout: %APPDATA%\Clipwell\{clips.sqlite, payloads\, settings.json}.
/// Mirrors the macOS layout under ~/Library/Application Support/ClipboardDrawer/.
/// The root is injectable so tests can point at a temp directory.
/// </summary>
public sealed class AppPaths
{
    public string Root { get; }

    public AppPaths(string? root = null)
    {
        Root = root ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "Clipwell");
        Directory.CreateDirectory(Root);
        Directory.CreateDirectory(PayloadsDirectory);
    }

    public string DatabasePath => Path.Combine(Root, "clips.sqlite");

    public string PayloadsDirectory => Path.Combine(Root, "payloads");

    public string SettingsPath => Path.Combine(Root, "settings.json");

    public string VocabularyPath => Path.Combine(Root, "vocabulary.json");
}

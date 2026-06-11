using System.Text.Json.Serialization;

namespace Clipwell.Core.Settings;

/// <summary>
/// Global hotkey stored as Win32 RegisterHotKey values:
/// Modifiers is a MOD_* bitmask (Alt=1, Ctrl=2, Shift=4, Win=8), Key is a virtual-key code.
/// </summary>
public sealed record HotkeyDefinition(uint Modifiers, uint Key)
{
    public const uint ModAlt = 0x0001;
    public const uint ModControl = 0x0002;
    public const uint ModShift = 0x0004;
    public const uint ModWin = 0x0008;

    /// <summary>Ctrl+Shift+V (VK 0x56) — Windows counterpart of the mac default Cmd+Shift+V.</summary>
    public static HotkeyDefinition DefaultToggleDrawer { get; } = new(ModControl | ModShift, 0x56);

    /// <summary>Alt+Shift+R (VK 0x52) — Windows counterpart of the mac default Option+Shift+R.</summary>
    public static HotkeyDefinition DefaultScreenshotOcr { get; } = new(ModAlt | ModShift, 0x52);

    [JsonIgnore]
    public string DisplayText
    {
        get
        {
            var parts = new List<string>();
            if ((Modifiers & ModControl) != 0) parts.Add("Ctrl");
            if ((Modifiers & ModAlt) != 0) parts.Add("Alt");
            if ((Modifiers & ModShift) != 0) parts.Add("Shift");
            if ((Modifiers & ModWin) != 0) parts.Add("Win");
            parts.Add(KeyDisplayName(Key));
            return string.Join("+", parts);
        }
    }

    private static string KeyDisplayName(uint vk) => vk switch
    {
        >= 0x30 and <= 0x39 => ((char)vk).ToString(),          // 0-9
        >= 0x41 and <= 0x5A => ((char)vk).ToString(),          // A-Z
        >= 0x70 and <= 0x87 => $"F{vk - 0x6F}",                // F1-F24
        0x20 => "Space",
        0x0D => "Enter",
        _ => $"0x{vk:X2}",
    };
}

/// <summary>
/// User settings persisted to %APPDATA%\Clipwell\settings.json.
/// Field set mirrors the MVP-relevant keys of the macOS SettingsStore.
/// </summary>
public sealed class AppSettings
{
    public int HistoryMaxCount { get; set; } = 500;
    public bool MonitoringPaused { get; set; }
    public bool LaunchAtLoginEnabled { get; set; }
    public HotkeyDefinition ToggleDrawerHotkey { get; set; } = HotkeyDefinition.DefaultToggleDrawer;
    public bool DedupConsecutiveEnabled { get; set; } = true;
    public bool AutoPasteEnabled { get; set; }
    public bool AutoCloseDrawerEnabled { get; set; } = true;
    public string IgnoredAppListText { get; set; } = "";
    public string IgnoredFileExtensionsText { get; set; } = "";
    public string DrawerEdge { get; set; } = "right";
    public double DrawerWidth { get; set; } = 420;
    public string Theme { get; set; } = "glassNight";

    // Pro features (mac: pro_* settings keys)
    public bool ProEnabled { get; set; } = true;
    public bool ProAIEnabled { get; set; } = true;
    public string ProAIBaseUrl { get; set; } = "http://127.0.0.1:4000/v1";
    public string ProAIApiKey { get; set; } = "";
    public string ProAIModel { get; set; } = "gpt-5.4-mini";
    public string ProTranslationTargetLanguage { get; set; } = "Simplified Chinese";
    public string ProOcrLanguagesText { get; set; } = "zh-Hans,en-US";
    public bool AutoOcrImagesEnabled { get; set; }
    public bool ProVocabularyEnabled { get; set; } = true;
    public HotkeyDefinition ScreenshotOcrHotkey { get; set; } = HotkeyDefinition.DefaultScreenshotOcr;
    public List<Pipeline.ClipPipelineStageConfiguration> PostCapturePipelineStages { get; set; } =
        Pipeline.BuiltInPluginIds.DefaultPostCaptureStages();
}

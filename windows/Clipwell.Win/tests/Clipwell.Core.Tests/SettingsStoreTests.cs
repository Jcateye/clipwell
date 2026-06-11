using Clipwell.Core.Settings;
using Xunit;

namespace Clipwell.Core.Tests;

public sealed class SettingsStoreTests : IDisposable
{
    private readonly string _tempDir;
    private readonly string _settingsPath;

    public SettingsStoreTests()
    {
        _tempDir = Directory.CreateTempSubdirectory("clipwell-settings-").FullName;
        _settingsPath = Path.Combine(_tempDir, "settings.json");
    }

    public void Dispose() => Directory.Delete(_tempDir, recursive: true);

    [Fact]
    public void MissingFileYieldsDefaults()
    {
        var store = new SettingsStore(_settingsPath);

        Assert.Equal(500, store.Current.HistoryMaxCount);
        Assert.True(store.Current.DedupConsecutiveEnabled);
        Assert.True(store.Current.AutoCloseDrawerEnabled);
        Assert.False(store.Current.MonitoringPaused);
        Assert.False(store.Current.AutoPasteEnabled);
        Assert.Equal("right", store.Current.DrawerEdge);
        Assert.Equal(420, store.Current.DrawerWidth);
        Assert.Equal(HotkeyDefinition.DefaultToggleDrawer, store.Current.ToggleDrawerHotkey);
    }

    [Fact]
    public void SaveAndReloadRoundTrips()
    {
        var store = new SettingsStore(_settingsPath);
        store.Update(settings =>
        {
            settings.HistoryMaxCount = 200;
            settings.MonitoringPaused = true;
            settings.IgnoredAppListText = "KeePass\n1Password";
            settings.ToggleDrawerHotkey = new HotkeyDefinition(HotkeyDefinition.ModControl | HotkeyDefinition.ModAlt, 0x43);
        });

        var reloaded = new SettingsStore(_settingsPath);
        Assert.Equal(200, reloaded.Current.HistoryMaxCount);
        Assert.True(reloaded.Current.MonitoringPaused);
        Assert.Equal("KeePass\n1Password", reloaded.Current.IgnoredAppListText);
        Assert.Equal(new HotkeyDefinition(HotkeyDefinition.ModControl | HotkeyDefinition.ModAlt, 0x43), reloaded.Current.ToggleDrawerHotkey);
    }

    [Fact]
    public void CorruptFileFallsBackToDefaults()
    {
        File.WriteAllText(_settingsPath, "{not valid json!!");
        var store = new SettingsStore(_settingsPath);
        Assert.Equal(500, store.Current.HistoryMaxCount);
    }

    [Fact]
    public void ShouldIgnoreAppMatchesExactAndSubstringCaseInsensitive()
    {
        var store = new SettingsStore(_settingsPath);
        store.Update(settings => settings.IgnoredAppListText = "KeePass\n  Bitwarden  \n");

        Assert.True(store.ShouldIgnoreApp("keepass"));
        Assert.True(store.ShouldIgnoreApp("KeePassXC"));
        Assert.True(store.ShouldIgnoreApp("Bitwarden"));
        Assert.False(store.ShouldIgnoreApp("Notepad"));
        Assert.False(store.ShouldIgnoreApp(null));
    }

    [Fact]
    public void ShouldIgnoreAppWithEmptyListIgnoresNothing()
    {
        var store = new SettingsStore(_settingsPath);
        Assert.False(store.ShouldIgnoreApp("AnyApp"));
    }

    [Fact]
    public void IgnoredFileExtensionsParsesSeparatorsAndDots()
    {
        var store = new SettingsStore(_settingsPath);
        store.Update(settings => settings.IgnoredFileExtensionsText = ".PNG, jpg; mov\n txt\tpdf");

        Assert.Equal(["jpg", "mov", "pdf", "png", "txt"], store.IgnoredFileExtensions.OrderBy(ext => ext));
    }

    [Fact]
    public void HotkeyDisplayTextFormatsModifiers()
    {
        Assert.Equal("Ctrl+Shift+V", HotkeyDefinition.DefaultToggleDrawer.DisplayText);
        Assert.Equal("Ctrl+Alt+F2", new HotkeyDefinition(
            HotkeyDefinition.ModControl | HotkeyDefinition.ModAlt, 0x71).DisplayText);
    }
}

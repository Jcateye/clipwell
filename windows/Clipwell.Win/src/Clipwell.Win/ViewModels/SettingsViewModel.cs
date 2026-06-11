using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Clipwell.Core.Settings;
using Clipwell.Win.Services;

namespace Clipwell.Win.ViewModels;

public partial class SettingsViewModel : ObservableObject
{
    private readonly SettingsStore _settings;
    private readonly StartupService _startupService;

    [ObservableProperty] private int _historyMaxCount;
    [ObservableProperty] private bool _monitoringPaused;
    [ObservableProperty] private bool _launchAtLoginEnabled;
    [ObservableProperty] private bool _dedupConsecutiveEnabled;
    [ObservableProperty] private bool _autoCloseDrawerEnabled;
    [ObservableProperty] private string _ignoredAppListText = "";
    [ObservableProperty] private string _ignoredFileExtensionsText = "";
    [ObservableProperty] private string _drawerEdge = "right";
    [ObservableProperty] private double _drawerWidth = 420;
    [ObservableProperty] private string _hotkeyDisplayText = "";
    [ObservableProperty] private string _hotkeyStatusMessage = "";

    public SettingsViewModel(SettingsStore settings, StartupService startupService, HotkeyService hotkeyService)
    {
        _settings = settings;
        _startupService = startupService;
        hotkeyService.RegistrationFailed += (_, hotkey) =>
            HotkeyStatusMessage = $"Hotkey {hotkey.DisplayText} is in use by another app.";
        LoadFromSettings();
    }

    private void LoadFromSettings()
    {
        var current = _settings.Current;
        HistoryMaxCount = current.HistoryMaxCount;
        MonitoringPaused = current.MonitoringPaused;
        LaunchAtLoginEnabled = _startupService.IsEnabled;
        DedupConsecutiveEnabled = current.DedupConsecutiveEnabled;
        AutoCloseDrawerEnabled = current.AutoCloseDrawerEnabled;
        IgnoredAppListText = current.IgnoredAppListText;
        IgnoredFileExtensionsText = current.IgnoredFileExtensionsText;
        DrawerEdge = current.DrawerEdge;
        DrawerWidth = current.DrawerWidth;
        HotkeyDisplayText = current.ToggleDrawerHotkey.DisplayText;
    }

    [RelayCommand]
    private void Save()
    {
        _settings.Update(settings =>
        {
            settings.HistoryMaxCount = Math.Max(1, HistoryMaxCount);
            settings.MonitoringPaused = MonitoringPaused;
            settings.LaunchAtLoginEnabled = LaunchAtLoginEnabled;
            settings.DedupConsecutiveEnabled = DedupConsecutiveEnabled;
            settings.AutoCloseDrawerEnabled = AutoCloseDrawerEnabled;
            settings.IgnoredAppListText = IgnoredAppListText;
            settings.IgnoredFileExtensionsText = IgnoredFileExtensionsText;
            settings.DrawerEdge = DrawerEdge;
            settings.DrawerWidth = DrawerWidth;
        });
        _startupService.SetEnabled(LaunchAtLoginEnabled);
        HotkeyStatusMessage = "";
    }

    public void SetHotkey(HotkeyDefinition hotkey)
    {
        _settings.Update(settings => settings.ToggleDrawerHotkey = hotkey);
        HotkeyDisplayText = hotkey.DisplayText;
    }
}

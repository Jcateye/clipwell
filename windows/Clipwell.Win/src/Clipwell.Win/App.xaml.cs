using System.Windows;
using Clipwell.Core.Data;
using Clipwell.Core.Settings;
using Clipwell.Win.Interop;
using Clipwell.Win.Services;
using Clipwell.Win.ViewModels;
using Clipwell.Win.Views;

namespace Clipwell.Win;

/// <summary>
/// Composition root. Wires storage, clipboard monitoring, hotkey, tray, and windows.
/// A named mutex enforces a single running instance.
/// </summary>
public partial class App : Application
{
    private Mutex? _singleInstanceMutex;
    private MessageWindow? _messageWindow;
    private HotkeyService? _hotkeyService;
    private TrayService? _trayService;
    private ClipRepository? _repository;
    private DrawerWindow? _drawerWindow;
    private SettingsWindow? _settingsWindow;
    private SettingsViewModel? _settingsViewModel;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        _singleInstanceMutex = new Mutex(initiallyOwned: true, "Clipwell.Win.SingleInstance", out var createdNew);
        if (!createdNew)
        {
            Shutdown();
            return;
        }

        var paths = new AppPaths();
        var settings = new SettingsStore(paths.SettingsPath);
        _repository = new ClipRepository(paths.DatabasePath);
        var payloadStore = new PayloadStore(paths.PayloadsDirectory);

        _messageWindow = new MessageWindow();
        var monitor = new ClipboardMonitorService(
            _messageWindow, _repository, payloadStore, settings,
            new ClipboardReader(), new ForegroundAppService());
        var restoreService = new ClipRestoreService(payloadStore, monitor);

        var drawerViewModel = new DrawerViewModel(_repository, payloadStore, restoreService, monitor);
        _drawerWindow = new DrawerWindow(drawerViewModel, settings);

        _hotkeyService = new HotkeyService(_messageWindow, settings);
        _hotkeyService.ToggleDrawerRequested += (_, _) => _drawerWindow.Toggle();

        var startupService = new StartupService();
        _settingsViewModel = new SettingsViewModel(settings, startupService, _hotkeyService);

        _trayService = new TrayService(
            settings,
            toggleDrawer: () => _drawerWindow.Toggle(),
            openSettings: ShowSettingsWindow,
            quit: Shutdown);
    }

    private void ShowSettingsWindow()
    {
        if (_settingsWindow is { IsLoaded: true })
        {
            _settingsWindow.Activate();
            return;
        }
        _settingsWindow = new SettingsWindow(_settingsViewModel!);
        _settingsWindow.Show();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _trayService?.Dispose();
        _hotkeyService?.Dispose();
        _messageWindow?.Dispose();
        _repository?.Dispose();
        _singleInstanceMutex?.Dispose();
        base.OnExit(e);
    }
}

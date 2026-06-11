using System.IO;
using System.Windows;
using System.Windows.Controls;
using H.NotifyIcon;
using Clipwell.Core.Settings;

namespace Clipwell.Win.Services;

/// <summary>
/// System tray icon (mac: MenuBarController). Left click toggles the drawer;
/// context menu offers toggle, pause monitoring, settings, and quit.
/// </summary>
public sealed class TrayService : IDisposable
{
    private readonly TaskbarIcon _trayIcon;
    private readonly MenuItem _pauseItem;

    public TrayService(
        SettingsStore settings,
        Action toggleDrawer,
        Action openSettings,
        Action openVocabulary,
        Action quit)
    {
        _pauseItem = new MenuItem
        {
            Header = "Pause Monitoring",
            IsCheckable = true,
            IsChecked = settings.Current.MonitoringPaused,
        };
        _pauseItem.Click += (_, _) =>
            settings.Update(current => current.MonitoringPaused = _pauseItem.IsChecked);
        settings.SettingsChanged += (_, _) =>
            _pauseItem.IsChecked = settings.Current.MonitoringPaused;

        var toggleItem = new MenuItem { Header = "Toggle Drawer" };
        toggleItem.Click += (_, _) => toggleDrawer();

        var settingsItem = new MenuItem { Header = "Settings..." };
        settingsItem.Click += (_, _) => openSettings();

        var vocabularyItem = new MenuItem { Header = "Vocabulary..." };
        vocabularyItem.Click += (_, _) => openVocabulary();

        var quitItem = new MenuItem { Header = "Quit Clipwell" };
        quitItem.Click += (_, _) => quit();

        var menu = new ContextMenu();
        menu.Items.Add(toggleItem);
        menu.Items.Add(_pauseItem);
        menu.Items.Add(vocabularyItem);
        menu.Items.Add(settingsItem);
        menu.Items.Add(new Separator());
        menu.Items.Add(quitItem);

        _trayIcon = new TaskbarIcon
        {
            ToolTipText = "Clipwell",
            ContextMenu = menu,
        };
        var iconUri = new Uri("pack://application:,,,/Assets/clipwell.ico", UriKind.Absolute);
        try
        {
            _trayIcon.IconSource = new System.Windows.Media.Imaging.BitmapImage(iconUri);
        }
        catch (IOException)
        {
            // Missing icon asset: tray still works with the default icon.
        }
        _trayIcon.LeftClickCommand = new RelayActionCommand(toggleDrawer);
        _trayIcon.ForceCreate();
    }

    public void Dispose() => _trayIcon.Dispose();

    private sealed class RelayActionCommand(Action action) : System.Windows.Input.ICommand
    {
        public event EventHandler? CanExecuteChanged { add { } remove { } }
        public bool CanExecute(object? parameter) => true;
        public void Execute(object? parameter) => action();
    }
}

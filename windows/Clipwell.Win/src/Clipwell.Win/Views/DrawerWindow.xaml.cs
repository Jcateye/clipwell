using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Threading;
using Clipwell.Core.Models;
using Clipwell.Core.Settings;
using Clipwell.Win.Interop;
using Clipwell.Win.ViewModels;

namespace Clipwell.Win.Views;

/// <summary>
/// Borderless drawer docked to a screen edge (mac: DrawerWindowController).
/// Toggled by the global hotkey or tray icon; hides on Esc or focus loss
/// when AutoCloseDrawerEnabled.
/// </summary>
public partial class DrawerWindow : Window
{
    private readonly DrawerViewModel _viewModel;
    private readonly SettingsStore _settings;

    /// <summary>Window that was focused before the drawer opened — the auto-paste target.</summary>
    private IntPtr _previousForegroundWindow;

    public DrawerWindow(DrawerViewModel viewModel, SettingsStore settings)
    {
        InitializeComponent();
        _viewModel = viewModel;
        _settings = settings;
        DataContext = viewModel;
        viewModel.ClipRestored += (_, _) => OnClipRestored();
    }

    private void OnClipRestored()
    {
        var autoPaste = _settings.Current.AutoPasteEnabled && _previousForegroundWindow != IntPtr.Zero;
        if (_settings.Current.AutoCloseDrawerEnabled || autoPaste)
        {
            Hide();
        }
        if (autoPaste)
        {
            var target = _previousForegroundWindow;
            // Give focus a beat to return to the target window before synthesizing Ctrl+V.
            Dispatcher.BeginInvoke(DispatcherPriority.Background, () =>
            {
                NativeMethods.SetForegroundWindow(target);
                Dispatcher.BeginInvoke(DispatcherPriority.ApplicationIdle, NativeMethods.SendCtrlV);
            });
        }
    }

    public void Toggle()
    {
        if (IsVisible)
        {
            Hide();
        }
        else
        {
            ShowDocked();
        }
    }

    public void ShowDocked()
    {
        _previousForegroundWindow = NativeMethods.GetForegroundWindow();
        var workArea = SystemParameters.WorkArea;
        Width = _settings.Current.DrawerWidth;
        Height = workArea.Height;
        Top = workArea.Top;
        Left = _settings.Current.DrawerEdge == "left"
            ? workArea.Left
            : workArea.Right - Width;

        _viewModel.Refresh();
        Show();
        Activate();
        SearchBox.Focus();
    }

    private void OnDeactivated(object sender, EventArgs e)
    {
        if (_settings.Current.AutoCloseDrawerEnabled && IsVisible)
        {
            Hide();
        }
    }

    private void OnPreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Escape)
        {
            Hide();
            e.Handled = true;
        }
    }

    private void OnItemDoubleClick(object sender, MouseButtonEventArgs e)
    {
        if (sender is ListBox { SelectedItem: ClipItem clip })
        {
            _viewModel.RestoreCommand.Execute(clip);
        }
    }

    protected override void OnClosing(System.ComponentModel.CancelEventArgs e)
    {
        // The drawer lives for the whole app session; closing just hides it.
        e.Cancel = true;
        Hide();
    }
}

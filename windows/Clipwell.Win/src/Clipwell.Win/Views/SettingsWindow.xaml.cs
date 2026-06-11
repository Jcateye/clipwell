using System.Windows;
using System.Windows.Input;
using Clipwell.Core.Settings;
using Clipwell.Win.ViewModels;

namespace Clipwell.Win.Views;

public partial class SettingsWindow : Window
{
    private readonly SettingsViewModel _viewModel;

    public SettingsWindow(SettingsViewModel viewModel)
    {
        InitializeComponent();
        _viewModel = viewModel;
        DataContext = viewModel;
    }

    private void OnSaveClicked(object sender, RoutedEventArgs e) => Close();

    private void OnHotkeyBoxKeyDown(object sender, KeyEventArgs e)
    {
        e.Handled = true;
        var key = e.Key == Key.System ? e.SystemKey : e.Key;
        if (key is Key.LeftCtrl or Key.RightCtrl or Key.LeftAlt or Key.RightAlt
            or Key.LeftShift or Key.RightShift or Key.LWin or Key.RWin)
        {
            return; // Wait for a non-modifier key.
        }

        uint modifiers = 0;
        if (Keyboard.Modifiers.HasFlag(ModifierKeys.Control)) modifiers |= HotkeyDefinition.ModControl;
        if (Keyboard.Modifiers.HasFlag(ModifierKeys.Alt)) modifiers |= HotkeyDefinition.ModAlt;
        if (Keyboard.Modifiers.HasFlag(ModifierKeys.Shift)) modifiers |= HotkeyDefinition.ModShift;
        if (Keyboard.Modifiers.HasFlag(ModifierKeys.Windows)) modifiers |= HotkeyDefinition.ModWin;
        if (modifiers == 0)
        {
            return; // Global hotkeys need at least one modifier.
        }

        var virtualKey = (uint)KeyInterop.VirtualKeyFromKey(key);
        _viewModel.SetHotkey(new HotkeyDefinition(modifiers, virtualKey));
    }
}

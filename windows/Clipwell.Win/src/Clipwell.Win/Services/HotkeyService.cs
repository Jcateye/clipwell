using Clipwell.Core.Settings;
using Clipwell.Win.Interop;

namespace Clipwell.Win.Services;

/// <summary>
/// Registers the global toggle-drawer hotkey against the hidden message window
/// and re-registers whenever settings change. Registration failure (conflict with
/// another app) is surfaced via RegistrationFailed for the settings UI.
/// </summary>
public sealed class HotkeyService : IDisposable
{
    private const int ToggleDrawerHotkeyId = 1;

    private readonly MessageWindow _messageWindow;
    private readonly SettingsStore _settings;
    private bool _registered;

    public event EventHandler? ToggleDrawerRequested;
    public event EventHandler<HotkeyDefinition>? RegistrationFailed;

    public HotkeyService(MessageWindow messageWindow, SettingsStore settings)
    {
        _messageWindow = messageWindow;
        _settings = settings;

        _messageWindow.HotkeyPressed += (_, id) =>
        {
            if (id == ToggleDrawerHotkeyId)
            {
                ToggleDrawerRequested?.Invoke(this, EventArgs.Empty);
            }
        };
        _settings.SettingsChanged += (_, _) => Register();
        Register();
    }

    public void Register()
    {
        Unregister();
        var hotkey = _settings.Current.ToggleDrawerHotkey;
        _registered = NativeMethods.RegisterHotKey(
            _messageWindow.Handle, ToggleDrawerHotkeyId, hotkey.Modifiers, hotkey.Key);
        if (!_registered)
        {
            RegistrationFailed?.Invoke(this, hotkey);
        }
    }

    private void Unregister()
    {
        if (_registered)
        {
            NativeMethods.UnregisterHotKey(_messageWindow.Handle, ToggleDrawerHotkeyId);
            _registered = false;
        }
    }

    public void Dispose() => Unregister();
}

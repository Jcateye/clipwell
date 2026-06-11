using Clipwell.Core.Settings;
using Clipwell.Win.Interop;

namespace Clipwell.Win.Services;

/// <summary>
/// Registers the global hotkeys (toggle drawer, screenshot OCR) against the hidden
/// message window and re-registers whenever settings change. Registration failure
/// (conflict with another app) is surfaced via RegistrationFailed for the settings UI.
/// </summary>
public sealed class HotkeyService : IDisposable
{
    private const int ToggleDrawerHotkeyId = 1;
    private const int ScreenshotOcrHotkeyId = 2;

    private readonly MessageWindow _messageWindow;
    private readonly SettingsStore _settings;
    private readonly HashSet<int> _registeredIds = [];

    public event EventHandler? ToggleDrawerRequested;
    public event EventHandler? ScreenshotOcrRequested;
    public event EventHandler<HotkeyDefinition>? RegistrationFailed;

    public HotkeyService(MessageWindow messageWindow, SettingsStore settings)
    {
        _messageWindow = messageWindow;
        _settings = settings;

        _messageWindow.HotkeyPressed += (_, id) =>
        {
            switch (id)
            {
                case ToggleDrawerHotkeyId:
                    ToggleDrawerRequested?.Invoke(this, EventArgs.Empty);
                    break;
                case ScreenshotOcrHotkeyId:
                    ScreenshotOcrRequested?.Invoke(this, EventArgs.Empty);
                    break;
            }
        };
        _settings.SettingsChanged += (_, _) => Register();
        Register();
    }

    public void Register()
    {
        Unregister();
        RegisterOne(ToggleDrawerHotkeyId, _settings.Current.ToggleDrawerHotkey);
        if (_settings.Current.ProEnabled)
        {
            RegisterOne(ScreenshotOcrHotkeyId, _settings.Current.ScreenshotOcrHotkey);
        }
    }

    private void RegisterOne(int id, HotkeyDefinition hotkey)
    {
        if (NativeMethods.RegisterHotKey(_messageWindow.Handle, id, hotkey.Modifiers, hotkey.Key))
        {
            _registeredIds.Add(id);
        }
        else
        {
            RegistrationFailed?.Invoke(this, hotkey);
        }
    }

    private void Unregister()
    {
        foreach (var id in _registeredIds)
        {
            NativeMethods.UnregisterHotKey(_messageWindow.Handle, id);
        }
        _registeredIds.Clear();
    }

    public void Dispose() => Unregister();
}

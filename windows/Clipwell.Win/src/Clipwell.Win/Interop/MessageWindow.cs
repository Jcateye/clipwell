using System.Windows.Interop;

namespace Clipwell.Win.Interop;

/// <summary>
/// Hidden message-only window that owns all Win32 message plumbing:
/// receives WM_CLIPBOARDUPDATE (after AddClipboardFormatListener) and WM_HOTKEY,
/// and surfaces them as .NET events. Hotkeys are registered against this window's handle.
/// </summary>
public sealed class MessageWindow : IDisposable
{
    private readonly HwndSource _source;
    private bool _listeningToClipboard;

    public IntPtr Handle => _source.Handle;

    public event EventHandler? ClipboardUpdated;
    public event EventHandler<int>? HotkeyPressed;

    public MessageWindow()
    {
        var parameters = new HwndSourceParameters("ClipwellMessageWindow")
        {
            Width = 0,
            Height = 0,
            WindowStyle = 0,
            ExtendedWindowStyle = 0,
            ParentWindow = new IntPtr(-3), // HWND_MESSAGE: message-only window
        };
        _source = new HwndSource(parameters);
        _source.AddHook(WndProc);
    }

    public void StartClipboardListener()
    {
        if (!_listeningToClipboard)
        {
            _listeningToClipboard = NativeMethods.AddClipboardFormatListener(Handle);
        }
    }

    private IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        switch (msg)
        {
            case NativeMethods.WM_CLIPBOARDUPDATE:
                ClipboardUpdated?.Invoke(this, EventArgs.Empty);
                handled = true;
                break;
            case NativeMethods.WM_HOTKEY:
                HotkeyPressed?.Invoke(this, wParam.ToInt32());
                handled = true;
                break;
        }
        return IntPtr.Zero;
    }

    public void Dispose()
    {
        if (_listeningToClipboard)
        {
            NativeMethods.RemoveClipboardFormatListener(Handle);
            _listeningToClipboard = false;
        }
        _source.RemoveHook(WndProc);
        _source.Dispose();
    }
}

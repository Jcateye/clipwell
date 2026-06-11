using System.Diagnostics;
using Clipwell.Win.Interop;

namespace Clipwell.Win.Services;

/// <summary>Identifies the foreground application (clip source) at copy time.</summary>
public sealed class ForegroundAppService
{
    public string? ForegroundAppName()
    {
        try
        {
            var hwnd = NativeMethods.GetForegroundWindow();
            if (hwnd == IntPtr.Zero)
            {
                return null;
            }
            NativeMethods.GetWindowThreadProcessId(hwnd, out var processId);
            if (processId == 0)
            {
                return null;
            }
            using var process = Process.GetProcessById((int)processId);
            return process.ProcessName;
        }
        catch (Exception ex) when (ex is ArgumentException or InvalidOperationException)
        {
            return null;
        }
    }

    public IntPtr ForegroundWindowHandle() => NativeMethods.GetForegroundWindow();
}

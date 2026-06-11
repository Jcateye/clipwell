using System.Collections.Specialized;
using System.IO;
using System.Text;
using System.Windows;
using System.Windows.Media.Imaging;
using Clipwell.Core.Data;
using Clipwell.Core.Models;

namespace Clipwell.Win.Services;

/// <summary>
/// Writes a history clip back to the system clipboard by type, marking it as a
/// self-copy so the monitor does not re-capture it.
/// </summary>
public sealed class ClipRestoreService
{
    private readonly PayloadStore _payloadStore;
    private readonly ClipboardMonitorService _monitor;

    public ClipRestoreService(PayloadStore payloadStore, ClipboardMonitorService monitor)
    {
        _payloadStore = payloadStore;
        _monitor = monitor;
    }

    public bool Restore(ClipItem clip)
    {
        _monitor.MarkSelfCopy(clip.ContentHash);
        try
        {
            switch (clip.Type)
            {
                case ClipType.Text:
                    if (clip.PlainText is null) return false;
                    Clipboard.SetText(clip.PlainText);
                    return true;

                case ClipType.Rtf:
                    return RestoreRichText(clip, DataFormats.Rtf);

                case ClipType.Html:
                    return RestoreRichText(clip, DataFormats.Html);

                case ClipType.Media:
                case ClipType.Document:
                    return RestoreFileOrImage(clip);

                default:
                    return false;
            }
        }
        catch (System.Runtime.InteropServices.ExternalException)
        {
            return false;
        }
    }

    private bool RestoreRichText(ClipItem clip, string richFormat)
    {
        var dataObject = new DataObject();
        if (clip.PayloadPath is { } path && _payloadStore.Load(path) is { } payload)
        {
            dataObject.SetData(richFormat, Encoding.UTF8.GetString(payload));
        }
        if (clip.PlainText is { } text)
        {
            dataObject.SetData(DataFormats.UnicodeText, text);
        }
        Clipboard.SetDataObject(dataObject, copy: true);
        return true;
    }

    private bool RestoreFileOrImage(ClipItem clip)
    {
        // File-backed clip (document or media file copied from Explorer): restore as file drop.
        if (clip.PlainText is { } filePath && File.Exists(filePath))
        {
            var files = new StringCollection { filePath };
            Clipboard.SetFileDropList(files);
            return true;
        }

        // Raw image payload captured from the clipboard: restore as bitmap.
        if (clip.PayloadPath is { } payloadPath && File.Exists(payloadPath))
        {
            var bitmap = new BitmapImage();
            bitmap.BeginInit();
            bitmap.UriSource = new Uri(payloadPath);
            bitmap.CacheOption = BitmapCacheOption.OnLoad;
            bitmap.EndInit();
            Clipboard.SetImage(bitmap);
            return true;
        }

        return false;
    }
}

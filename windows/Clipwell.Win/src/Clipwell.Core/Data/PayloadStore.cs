namespace Clipwell.Core.Data;

/// <summary>
/// Stores binary clip payloads (PNG images, RTF, HTML) as files named {clipId}.{extension}
/// under the payloads directory — same naming convention as the macOS PayloadStore.
/// </summary>
public sealed class PayloadStore
{
    private readonly string _directory;

    public PayloadStore(string directory)
    {
        _directory = directory;
        Directory.CreateDirectory(_directory);
    }

    public string Save(string clipId, string extension, byte[] data)
    {
        var path = Path.Combine(_directory, $"{clipId}.{extension}");
        File.WriteAllBytes(path, data);
        return path;
    }

    public byte[]? Load(string path) => File.Exists(path) ? File.ReadAllBytes(path) : null;

    public void Delete(string? path)
    {
        if (string.IsNullOrEmpty(path))
        {
            return;
        }
        try
        {
            if (File.Exists(path))
            {
                File.Delete(path);
            }
        }
        catch (IOException)
        {
            // Best effort: a locked payload file is cleaned up on a later pass.
        }
    }

    public void DeleteAll(IEnumerable<string> paths)
    {
        foreach (var path in paths)
        {
            Delete(path);
        }
    }
}

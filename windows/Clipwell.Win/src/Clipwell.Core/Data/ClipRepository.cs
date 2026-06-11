using Clipwell.Core.Models;
using Microsoft.Data.Sqlite;

namespace Clipwell.Core.Data;

/// <summary>
/// SQLite-backed clip history. The schema is a byte-for-byte mirror of the macOS app's
/// clips table (Sources/ClipboardDrawer/Data/Database/ClipRepository.swift):
/// timestamps stored as REAL Unix epoch seconds, enum columns store raw string values.
/// </summary>
public sealed class ClipRepository : IDisposable
{
    private readonly SqliteConnection _connection;

    public ClipRepository(string databasePath)
    {
        _connection = new SqliteConnection($"Data Source={databasePath}");
        _connection.Open();
        Migrate();
    }

    public void Insert(ClipItem clip)
    {
        using var command = _connection.CreateCommand();
        command.CommandText = """
            INSERT INTO clips (id, created_at, type, plain_text, payload_path, source_app, is_pinned, content_hash, origin, derived_from_clip_id)
            VALUES ($id, $createdAt, $type, $plainText, $payloadPath, $sourceApp, $isPinned, $contentHash, $origin, $derivedFromClipId)
            """;
        command.Parameters.AddWithValue("$id", clip.Id);
        command.Parameters.AddWithValue("$createdAt", clip.CreatedAt.ToUnixTimeMilliseconds() / 1000.0);
        command.Parameters.AddWithValue("$type", clip.Type.ToRaw());
        command.Parameters.AddWithValue("$plainText", (object?)clip.PlainText ?? DBNull.Value);
        command.Parameters.AddWithValue("$payloadPath", (object?)clip.PayloadPath ?? DBNull.Value);
        command.Parameters.AddWithValue("$sourceApp", (object?)clip.SourceApp ?? DBNull.Value);
        command.Parameters.AddWithValue("$isPinned", clip.IsPinned ? 1 : 0);
        command.Parameters.AddWithValue("$contentHash", clip.ContentHash);
        command.Parameters.AddWithValue("$origin", clip.Origin.ToRaw());
        command.Parameters.AddWithValue("$derivedFromClipId", (object?)clip.DerivedFromClipId ?? DBNull.Value);
        command.ExecuteNonQuery();
    }

    public IReadOnlyList<ClipItem> Fetch(string search = "", ClipFilter filter = ClipFilter.All, int limit = 500)
    {
        var clauses = new List<string>();
        using var command = _connection.CreateCommand();

        if (!string.IsNullOrWhiteSpace(search))
        {
            clauses.Add("plain_text LIKE $search");
            command.Parameters.AddWithValue("$search", $"%{search}%");
        }

        if (FilterClause(filter) is { } filterClause)
        {
            clauses.Add(filterClause);
        }

        var whereClause = clauses.Count == 0 ? "" : "WHERE " + string.Join(" AND ", clauses);
        command.CommandText = $"""
            SELECT id, created_at, type, plain_text, payload_path, source_app, is_pinned, content_hash, origin, derived_from_clip_id
            FROM clips
            {whereClause}
            ORDER BY is_pinned DESC, created_at DESC
            LIMIT $limit
            """;
        command.Parameters.AddWithValue("$limit", limit);

        var clips = new List<ClipItem>();
        using var reader = command.ExecuteReader();
        while (reader.Read())
        {
            if (ReadClip(reader) is { } clip)
            {
                clips.Add(clip);
            }
        }
        return clips;
    }

    public ClipItem? LatestClip() => Fetch(limit: 1).FirstOrDefault();

    public void SetPinned(string id, bool isPinned)
    {
        using var command = _connection.CreateCommand();
        command.CommandText = "UPDATE clips SET is_pinned = $isPinned WHERE id = $id";
        command.Parameters.AddWithValue("$isPinned", isPinned ? 1 : 0);
        command.Parameters.AddWithValue("$id", id);
        command.ExecuteNonQuery();
    }

    public void UpdatePlainText(string id, string text, string contentHash)
    {
        using var command = _connection.CreateCommand();
        command.CommandText = """
            UPDATE clips
            SET plain_text = $text, content_hash = $contentHash
            WHERE id = $id AND type = 'text'
            """;
        command.Parameters.AddWithValue("$text", text);
        command.Parameters.AddWithValue("$contentHash", contentHash);
        command.Parameters.AddWithValue("$id", id);
        command.ExecuteNonQuery();
    }

    public void Delete(string id)
    {
        using var command = _connection.CreateCommand();
        command.CommandText = "DELETE FROM clips WHERE id = $id";
        command.Parameters.AddWithValue("$id", id);
        command.ExecuteNonQuery();
    }

    public void Clear()
    {
        using var command = _connection.CreateCommand();
        command.CommandText = "DELETE FROM clips";
        command.ExecuteNonQuery();
    }

    public IReadOnlyList<string> PayloadPaths(ClipFilter filter = ClipFilter.All)
    {
        var whereClause = FilterClause(filter) is { } clause
            ? $"WHERE {clause} AND payload_path IS NOT NULL"
            : "WHERE payload_path IS NOT NULL";
        using var command = _connection.CreateCommand();
        command.CommandText = $"SELECT payload_path FROM clips {whereClause}";
        return ReadStrings(command);
    }

    /// <summary>Payload paths of unpinned clips that fall outside the newest maxCount, so files can be deleted before pruning.</summary>
    public IReadOnlyList<string> PayloadPathsBeyondLimit(int maxCount)
    {
        using var command = _connection.CreateCommand();
        command.CommandText = """
            SELECT payload_path FROM clips
            WHERE payload_path IS NOT NULL AND id IN (
                SELECT id FROM clips
                WHERE is_pinned = 0
                ORDER BY created_at DESC
                LIMIT -1 OFFSET $maxCount
            )
            """;
        command.Parameters.AddWithValue("$maxCount", maxCount);
        return ReadStrings(command);
    }

    /// <summary>Deletes unpinned clips beyond the newest maxCount. Pinned clips are never pruned.</summary>
    public void Prune(int maxCount)
    {
        using var command = _connection.CreateCommand();
        command.CommandText = """
            DELETE FROM clips
            WHERE id IN (
                SELECT id FROM clips
                WHERE is_pinned = 0
                ORDER BY created_at DESC
                LIMIT -1 OFFSET $maxCount
            )
            """;
        command.Parameters.AddWithValue("$maxCount", maxCount);
        command.ExecuteNonQuery();
    }

    public void Dispose()
    {
        _connection.Dispose();
        // Release the SQLite file handle held by the connection pool; without this,
        // deleting the database file right after Dispose fails on Windows.
        SqliteConnection.ClearPool(new SqliteConnection(_connection.ConnectionString));
    }

    private void Migrate()
    {
        string[] statements =
        [
            """
            CREATE TABLE IF NOT EXISTS clips (
                id TEXT PRIMARY KEY,
                created_at REAL NOT NULL,
                type TEXT NOT NULL,
                plain_text TEXT,
                payload_path TEXT,
                source_app TEXT,
                is_pinned INTEGER DEFAULT 0,
                content_hash TEXT,
                origin TEXT NOT NULL DEFAULT 'original',
                derived_from_clip_id TEXT
            )
            """,
            "CREATE INDEX IF NOT EXISTS idx_clips_created_at ON clips(created_at)",
            "CREATE INDEX IF NOT EXISTS idx_clips_type ON clips(type)",
            "CREATE INDEX IF NOT EXISTS idx_clips_plain_text ON clips(plain_text)",
        ];
        foreach (var sql in statements)
        {
            using var command = _connection.CreateCommand();
            command.CommandText = sql;
            command.ExecuteNonQuery();
        }
    }

    private static ClipItem? ReadClip(SqliteDataReader reader)
    {
        var type = ClipEnumValues.ClipTypeFromRaw(reader.GetString(2));
        if (type is null)
        {
            return null;
        }
        return new ClipItem(
            Id: reader.GetString(0),
            CreatedAt: DateTimeOffset.FromUnixTimeMilliseconds((long)(reader.GetDouble(1) * 1000)),
            Type: type.Value,
            PlainText: reader.IsDBNull(3) ? null : reader.GetString(3),
            PayloadPath: reader.IsDBNull(4) ? null : reader.GetString(4),
            SourceApp: reader.IsDBNull(5) ? null : reader.GetString(5),
            IsPinned: reader.GetInt32(6) == 1,
            ContentHash: reader.IsDBNull(7) ? "" : reader.GetString(7),
            Origin: ClipEnumValues.ClipOriginFromRaw(reader.IsDBNull(8) ? null : reader.GetString(8)),
            DerivedFromClipId: reader.IsDBNull(9) ? null : reader.GetString(9));
    }

    private static string? FilterClause(ClipFilter filter) => filter switch
    {
        ClipFilter.All => null,
        ClipFilter.Text => "type IN ('text', 'rtf', 'html')",
        ClipFilter.Media => "type = 'media'",
        ClipFilter.Document => "type = 'document'",
        _ => null,
    };

    private static List<string> ReadStrings(SqliteCommand command)
    {
        var values = new List<string>();
        using var reader = command.ExecuteReader();
        while (reader.Read())
        {
            if (!reader.IsDBNull(0))
            {
                values.Add(reader.GetString(0));
            }
        }
        return values;
    }
}

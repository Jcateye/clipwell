import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class ClipRepository {
    private var db: OpaquePointer?
    private let databaseURL: URL

    init(databaseURL: URL = AppPaths.databaseURL) {
        self.databaseURL = databaseURL
        open()
        migrate()
    }

    deinit {
        sqlite3_close(db)
    }

    func insert(_ clip: ClipItem) throws {
        let sql = """
        INSERT INTO clips (id, created_at, type, plain_text, payload_path, source_app, is_pinned, content_hash)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """
        try execute(sql) { statement in
            sqlite3_bind_text(statement, 1, clip.id, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(statement, 2, clip.createdAt.timeIntervalSince1970)
            sqlite3_bind_text(statement, 3, clip.type.rawValue, -1, SQLITE_TRANSIENT)
            bindOptionalText(statement, 4, clip.plainText)
            bindOptionalText(statement, 5, clip.payloadPath)
            bindOptionalText(statement, 6, clip.sourceApp)
            sqlite3_bind_int(statement, 7, clip.isPinned ? 1 : 0)
            sqlite3_bind_text(statement, 8, clip.contentHash, -1, SQLITE_TRANSIENT)
        }
    }

    func fetch(search: String = "", filter: ClipFilter = .all, limit: Int = 500) -> [ClipItem] {
        var clauses: [String] = []
        var values: [String] = []

        if !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            clauses.append("plain_text LIKE ?")
            values.append("%\(search)%")
        }

        if let filterClause = filterClause(for: filter) {
            clauses.append(filterClause)
        }

        let whereClause = clauses.isEmpty ? "" : "WHERE " + clauses.joined(separator: " AND ")
        let sql = """
        SELECT id, created_at, type, plain_text, payload_path, source_app, is_pinned, content_hash
        FROM clips
        \(whereClause)
        ORDER BY is_pinned DESC, created_at DESC
        LIMIT ?
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            AppLog.database.error("Fetch prepare failed: \(String(cString: sqlite3_errmsg(self.db)))")
            return []
        }
        defer { sqlite3_finalize(statement) }

        for (index, value) in values.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 1), value, -1, SQLITE_TRANSIENT)
        }
        sqlite3_bind_int(statement, Int32(values.count + 1), Int32(limit))

        var clips: [ClipItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let clip = readClip(from: statement) else { continue }
            clips.append(clip)
        }
        return clips
    }

    func latestClip() -> ClipItem? {
        fetch(limit: 1).first
    }

    func clear() {
        try? execute("DELETE FROM clips") { _ in }
    }

    func payloadPaths(matching filter: ClipFilter) -> [String] {
        let whereClause = filterClause(for: filter).map { "WHERE \($0) AND payload_path IS NOT NULL" } ?? "WHERE payload_path IS NOT NULL"
        let sql = "SELECT payload_path FROM clips \(whereClause)"

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        var paths: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let path = optionalColumn(statement, 0) {
                paths.append(path)
            }
        }
        return paths
    }

    func delete(matching filter: ClipFilter) {
        let whereClause = filterClause(for: filter).map { "WHERE \($0)" } ?? ""
        try? execute("DELETE FROM clips \(whereClause)") { _ in }
    }

    func payloadPathsBeyondLimit(maxCount: Int) -> [String] {
        let sql = """
        SELECT payload_path FROM clips
        WHERE payload_path IS NOT NULL AND id IN (
            SELECT id FROM clips
            WHERE is_pinned = 0
            ORDER BY created_at DESC
            LIMIT -1 OFFSET ?
        )
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(maxCount))
        var paths: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let path = optionalColumn(statement, 0) {
                paths.append(path)
            }
        }
        return paths
    }

    func prune(maxCount: Int) {
        let sql = """
        DELETE FROM clips
        WHERE id IN (
            SELECT id FROM clips
            WHERE is_pinned = 0
            ORDER BY created_at DESC
            LIMIT -1 OFFSET ?
        )
        """
        try? execute(sql) { statement in
            sqlite3_bind_int(statement, 1, Int32(maxCount))
        }
    }

    private func open() {
        if sqlite3_open(databaseURL.path, &db) != SQLITE_OK {
            AppLog.database.error("Unable to open database: \(self.databaseURL.path)")
        }
    }

    private func migrate() {
        let statements = [
            """
            CREATE TABLE IF NOT EXISTS clips (
                id TEXT PRIMARY KEY,
                created_at REAL NOT NULL,
                type TEXT NOT NULL,
                plain_text TEXT,
                payload_path TEXT,
                source_app TEXT,
                is_pinned INTEGER DEFAULT 0,
                content_hash TEXT
            )
            """,
            "CREATE INDEX IF NOT EXISTS idx_clips_created_at ON clips(created_at)",
            "CREATE INDEX IF NOT EXISTS idx_clips_type ON clips(type)",
            "CREATE INDEX IF NOT EXISTS idx_clips_plain_text ON clips(plain_text)",
            "UPDATE clips SET type = 'media' WHERE type = 'image'",
            """
            UPDATE clips
            SET type = 'media'
            WHERE type = 'document' AND plain_text IS NOT NULL AND (
                lower(plain_text) GLOB '*.jpg' OR
                lower(plain_text) GLOB '*.jpeg' OR
                lower(plain_text) GLOB '*.png' OR
                lower(plain_text) GLOB '*.gif' OR
                lower(plain_text) GLOB '*.heic' OR
                lower(plain_text) GLOB '*.webp' OR
                lower(plain_text) GLOB '*.tiff' OR
                lower(plain_text) GLOB '*.mp4' OR
                lower(plain_text) GLOB '*.mov' OR
                lower(plain_text) GLOB '*.m4v' OR
                lower(plain_text) GLOB '*.webm' OR
                lower(plain_text) GLOB '*.avi' OR
                lower(plain_text) GLOB '*.mkv'
            )
            """
        ]
        for sql in statements {
            try? execute(sql) { _ in }
        }
    }

    private func execute(_ sql: String, binder: (OpaquePointer?) -> Void) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw RepositoryError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }
        binder(statement)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw RepositoryError.executeFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func readClip(from statement: OpaquePointer?) -> ClipItem? {
        guard let idPointer = sqlite3_column_text(statement, 0),
              let typePointer = sqlite3_column_text(statement, 2),
              let hashPointer = sqlite3_column_text(statement, 7),
              let type = ClipType(rawValue: String(cString: typePointer)) else {
            return nil
        }

        return ClipItem(
            id: String(cString: idPointer),
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 1)),
            type: type,
            plainText: optionalColumn(statement, 3),
            payloadPath: optionalColumn(statement, 4),
            sourceApp: optionalColumn(statement, 5),
            isPinned: sqlite3_column_int(statement, 6) == 1,
            contentHash: String(cString: hashPointer)
        )
    }

    private func filterClause(for filter: ClipFilter) -> String? {
        switch filter {
        case .all:
            return nil
        case .text:
            return "type IN ('text', 'rtf', 'html')"
        case .media:
            return "type = 'media'"
        case .document:
            return "type = 'document'"
        }
    }

    private func optionalColumn(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let pointer = sqlite3_column_text(statement, index) else {
            return nil
        }
        return String(cString: pointer)
    }

    private func bindOptionalText(_ statement: OpaquePointer?, _ index: Int32, _ value: String?) {
        if let value {
            sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }
}

private enum RepositoryError: Error {
    case prepareFailed(String)
    case executeFailed(String)
}

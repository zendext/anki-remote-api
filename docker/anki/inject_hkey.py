#!/usr/bin/env python3
"""
Inject an AnkiWeb sync hkey into Anki's prefs21.db.

Anki stores sync credentials in prefs21.db under the 'profiles' table.
The profile data is a JSON-encoded blob that includes the 'syncKey' field.

Usage:
    inject_hkey.py <prefs21.db path> <profile name> <hkey>
"""
import json
import sqlite3
import sys


def inject(db_path: str, profile_name: str, hkey: str) -> None:
    conn = sqlite3.connect(db_path)
    try:
        cur = conn.cursor()

        # Ensure the profiles table exists (it may not on first run)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS profiles (
                name TEXT NOT NULL UNIQUE,
                data TEXT NOT NULL
            )
        """)

        row = cur.execute(
            "SELECT data FROM profiles WHERE name = ?", (profile_name,)
        ).fetchone()

        if row:
            try:
                data = json.loads(row[0])
            except json.JSONDecodeError:
                data = {}
        else:
            data = {}

        data["syncKey"] = hkey
        data["syncUser"] = ""  # Anki fills this in after first sync

        encoded = json.dumps(data)

        cur.execute(
            "INSERT OR REPLACE INTO profiles (name, data) VALUES (?, ?)",
            (profile_name, encoded),
        )
        conn.commit()
        print(f"[inject_hkey] hkey injected into profile '{profile_name}'")
    finally:
        conn.close()


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print(f"usage: {sys.argv[0]} <db_path> <profile_name> <hkey>", file=sys.stderr)
        sys.exit(1)
    inject(sys.argv[1], sys.argv[2], sys.argv[3])

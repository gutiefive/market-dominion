#!/usr/bin/env python3
"""Start the API as uid 10001.

Docker named volumes are root-owned. This process starts as root only long
enough to make ``/data`` writable, then drops to uid 10001 before uvicorn.
A non-root start skips the chown and execs uvicorn directly.
"""

from __future__ import annotations

import os
import pwd

DATA = "/data"
UID = 10001


def _hand_off_data() -> None:
    os.makedirs(DATA, exist_ok=True)
    os.chown(DATA, UID, UID)
    for name in os.listdir(DATA):
        path = os.path.join(DATA, name)
        try:
            os.chown(path, UID, UID)
        except OSError:
            continue


def main() -> None:
    host = os.environ.get("MD_HOST", "0.0.0.0")
    port = os.environ.get("MD_PORT", "8741")
    if os.geteuid() == 0:
        _hand_off_data()
        account = pwd.getpwuid(UID)
        os.initgroups(account.pw_name, account.pw_gid)
        os.setgid(account.pw_gid)
        os.setuid(account.pw_uid)
        os.environ["HOME"] = "/tmp"
    os.execvp(
        "uvicorn",
        ["uvicorn", "app.main:app", "--host", host, "--port", str(port)],
    )


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Store the user's existing AVARYN pilot password locally; never connects.

Interactive TTY only. No CLI login/PAT, password reset or network request.
Each run creates a new private generation; earlier credentials remain private
and untouched. connection.json atomically selects the latest generation.
"""
import argparse
import getpass
import json
import os
from pathlib import Path
import sys
import uuid

ROOT = Path(__file__).resolve().parents[3]
PROJECT_REF = "rvymglpkttlfwhqpmupp"
ORGANIZATION_ID = "ufvwcbrvwbqmejwraend"
SERVICE = "avaryn_c010_pilot"
TARGETS = {
    "session": ("aws-1-eu-west-1.pooler.supabase.com", "postgres." + PROJECT_REF),
    "direct": ("db." + PROJECT_REF + ".supabase.co", "postgres"),
}


def pgpass_entry(mode, password):
    if mode not in TARGETS or not password or any(c in password for c in "\r\n\0"):
        raise ValueError("Ongeldige invoer; niets opgeslagen.")
    host, user = TARGETS[mode]
    escape = lambda s: s.replace("\\", "\\\\").replace(":", "\\:")
    return ":".join(escape(s) for s in (host, "5432", "postgres", user, password)) + "\n"


def private_write(path, data):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w") as file:
        file.write(data)
    if path.stat().st_mode & 0o777 != 0o600:
        raise ValueError("Privébestandsrechten zijn niet correct.")


def store_connection(base, mode, password):
    # Fixed project/host/user; no arbitrary URL or destination credential input.
    entry = pgpass_entry(mode, password)
    for parent in [base, *base.parents]:
        if parent.is_symlink():
            raise ValueError("Symlink in privélocatie geweigerd.")
    base.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(base, 0o700)
    generation = base / ("connection-" + uuid.uuid4().hex)
    generation.mkdir(mode=0o700)
    host, user = TARGETS[mode]
    private_write(generation / "pgpass", entry)
    private_write(generation / "pg_service.conf", (
        f"[{SERVICE}]\nhost={host}\nport=5432\ndbname=postgres\nuser={user}\n"
        "sslmode=verify-full\nsslrootcert=system\nconnect_timeout=10\n"
        "application_name=avaryn-pilot-controlled-release\n"
    ))
    config = {
        "project_ref": PROJECT_REF, "organization_id": ORGANIZATION_ID,
        "project_name": "AVARYN C010 Pilot", "connection_mode": mode,
        "host": host, "port": 5432, "database": "postgres", "user": user,
        "sslmode": "verify-full", "sslrootcert": "system",
        "pgservice": SERVICE,
        "pgservicefile": str(generation / "pg_service.conf"),
        "pgpassfile": str(generation / "pgpass"),
        "connection_tested": False, "management_access": False,
    }
    encoded = json.dumps(config, indent=2) + "\n"
    private_write(generation / "connection.json", encoded)
    pointer = base / "connection.json"
    if pointer.is_symlink():
        raise ValueError("Symlink voor huidige verbinding geweigerd.")
    pending = base / (".connection-" + uuid.uuid4().hex + ".json")
    private_write(pending, encoded)
    os.replace(pending, pointer)
    return config


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--connection", choices=tuple(TARGETS), default="session",
                        help="session is de geverifieerde IPv4-sessionpooler op5432")
    args = parser.parse_args()
    if not sys.stdin.isatty() or not sys.stdout.isatty():
        parser.error("Voer dit zelf in een privéterminal uit; piped wachtwoorden worden geweigerd.")
    os.umask(0o077)
    print("Alleen AVARYN C010 Pilot. Voer het bestaande projectdatabasewachtwoord in.")
    password = getpass.getpass("Databasewachtwoord (onzichtbaar): ")
    if password != getpass.getpass("Nogmaals ter controle (onzichtbaar): "):
        raise ValueError("De invoer verschilt; niets opgeslagen.")
    base = ROOT / ".avaryn-local/productization-20260911/private/pilot-backend"
    store_connection(base, args.connection, password)
    print("Privéverbinding lokaal vastgelegd (0600). Er is nog geen netwerkverbinding gemaakt.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError) as error:
        # Never include a password-bearing exception or connection URL.
        print("Configuratie niet voltooid: " + (str(error) if isinstance(error, ValueError)
              else "privébestand kon niet veilig worden geschreven."), file=sys.stderr)
        sys.exit(1)

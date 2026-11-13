#!/usr/bin/env python3
"""Keep a private, local code-signing identity stable across development builds."""
import hashlib
import json
import os
from pathlib import Path
import secrets
import shlex
import subprocess
import sys
import tempfile


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout.strip()


def main():
    app = Path(sys.argv[1]).resolve()
    override = os.environ.get("KAPP_SIGNING_IDENTITY")
    if override:
        run("codesign", "--force", "--sign", override, str(app))
        run("codesign", "--verify", "--strict", str(app))
        return

    directory = Path.home() / "Library/Application Support/Kapp/Development"
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    config_file = directory / "signing.json"
    keychain = directory / "signing.keychain-db"
    if config_file.exists():
        config = json.loads(config_file.read_text())
    else:
        password = secrets.token_urlsafe(32)
        with tempfile.TemporaryDirectory() as temporary:
            temporary = Path(temporary)
            certificate = temporary / "certificate.pem"
            private_key = temporary / "key.pem"
            config_path = temporary / "certificate.cnf"
            config_path.write_text("""[req]
distinguished_name = name
x509_extensions = extensions
prompt = no
[name]
CN = Kapp Local Development
[extensions]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = codeSigning
subjectKeyIdentifier = hash
""")
            run("/usr/bin/openssl", "req", "-new", "-x509", "-newkey", "rsa:2048", "-sha256",
                "-nodes", "-days", "3650", "-config", str(config_path),
                "-keyout", str(private_key), "-out", str(certificate))
            der = temporary / "certificate.der"
            run("/usr/bin/openssl", "x509", "-in", str(certificate), "-outform", "DER", "-out", str(der))
            identity = hashlib.sha1(der.read_bytes()).hexdigest().upper()
            archive = temporary / "identity.p12"
            run("/usr/bin/openssl", "pkcs12", "-export", "-inkey", str(private_key),
                "-in", str(certificate), "-out", str(archive), "-passout", "pass:" + password)
            run("security", "create-keychain", "-p", password, str(keychain))
            run("security", "unlock-keychain", "-p", password, str(keychain))
            run("security", "import", str(archive), "-k", str(keychain), "-P", password,
                "-T", "/usr/bin/codesign")
            run("security", "set-key-partition-list", "-S", "codesign:", "-s", "-k", password, str(keychain))
            config = {"password": password, "identity": identity}
            config_file.write_text(json.dumps(config))
            config_file.chmod(0o600)

    if "--trust" in sys.argv:
        with tempfile.TemporaryDirectory() as temporary:
            certificate = Path(temporary) / "certificate.pem"
            certificate.write_text(run("security", "find-certificate", "-c", "Kapp Local Development", "-p", str(keychain)))
            run("security", "add-trusted-cert", "-r", "trustRoot", "-p", "codeSign", "-k", str(keychain), str(certificate))
    run("security", "unlock-keychain", "-p", config["password"], str(keychain))
    search_list = shlex.split(run("security", "list-keychains", "-d", "user"))
    try:
        run("security", "list-keychains", "-d", "user", "-s", *search_list, str(keychain))
        run("codesign", "--force", "--sign", config["identity"], "--keychain", str(keychain),
            "--timestamp=none", str(app))
    finally:
        run("security", "list-keychains", "-d", "user", "-s", *search_list)
    run("codesign", "--verify", "--strict", str(app))
    print("Signed with the persistent Kapp local development identity.")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        # Do not print command arguments: keychain operations include a local password.
        print(Path(error.cmd[0]).name + ": " + (error.stderr.strip() or "Local signing failed."), file=sys.stderr)
        print("For first-time local setup, rerun this script with --trust to trust only the Kapp code-signing certificate.", file=sys.stderr)
        sys.exit(1)

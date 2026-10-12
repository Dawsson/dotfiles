#!/usr/bin/env python3
"""Stdlib helpers for the dotfiles bootstrap."""

import argparse
import ast
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

UA = "dawsson-dotfiles"


def _github_token():
    for key in ("GH_TOKEN", "GITHUB_TOKEN"):
        value = (os.environ.get(key) or "").strip()
        if value:
            return value
    try:
        proc = subprocess.run(
            ["gh", "auth", "token"],
            check=False,
            capture_output=True,
            text=True,
            timeout=15,
        )
    except (OSError, subprocess.TimeoutExpired):
        return ""
    if proc.returncode == 0:
        return proc.stdout.strip()
    return ""


def _request(url):
    headers = {"Accept": "application/vnd.github+json", "User-Agent": UA}
    token = _github_token()
    if token:
        headers["Authorization"] = "Bearer {0}".format(token)
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as exc:
        if exc.code in (403, 429):
            print(
                "GitHub API HTTP {0} for {1}. Unauthenticated calls are rate limited; "
                "`gh auth login` raises the limit.".format(exc.code, url),
                file=sys.stderr,
            )
        raise


def cmd_github_asset(args):
    data = _request(
        "https://api.github.com/repos/{0}/releases/latest".format(args.repo)
    )
    regex = re.compile(args.regex)
    for asset in data.get("assets") or []:
        name = asset.get("name") or ""
        if regex.search(name):
            print(asset["browser_download_url"])
            return 0
    print(
        "no asset in {0} matched {1}".format(args.repo, args.regex),
        file=sys.stderr,
    )
    return 1


def cmd_t3_nightly(args):
    data = _request(
        "https://api.github.com/repos/pingdotgg/t3code/releases?per_page=40"
    )
    arch = args.arch
    if arch in ("amd64", "x64"):
        arch = "x86_64"
    if arch == "arm64":
        arch = "aarch64"
    for rel in data:
        tag = (rel.get("tag_name") or "").lower()
        if "nightly" not in tag:
            continue
        assets = {
            a["name"]: a["browser_download_url"] for a in rel.get("assets") or []
        }
        if arch == "x86_64":
            rpm = [
                name
                for name in assets
                if name.endswith(".rpm") and ("x86_64" in name or "amd64" in name)
            ]
            app = [
                name
                for name in assets
                if name.endswith(".AppImage") and "x86_64" in name
            ]
        else:
            rpm = [
                name
                for name in assets
                if name.endswith(".rpm") and ("aarch64" in name or "arm64" in name)
            ]
            app = [
                name for name in assets if name.endswith(".AppImage") and "arm64" in name
            ]
        if rpm:
            print("rpm")
            print(assets[sorted(rpm)[0]])
            return 0
        if app:
            print("appimage")
            print(assets[sorted(app)[0]])
            return 0
    print("no T3 Code nightly desktop build found", file=sys.stderr)
    return 1


def _section(text, header):
    lines = text.splitlines(keepends=True)
    start = None
    for index, line in enumerate(lines):
        if line.strip() == header:
            start = index
            break
    if start is None:
        return ""
    end = len(lines)
    for index in range(start + 1, len(lines)):
        stripped = lines[index].lstrip()
        if stripped.startswith("[") and not stripped.startswith("#"):
            end = index
            break
    return "".join(lines[start:end]).strip() + "\n"


def _without_section(text, header):
    lines = text.splitlines(keepends=True)
    out = []
    skipping = False
    for line in lines:
        if line.strip() == header:
            skipping = True
            continue
        if skipping:
            stripped = line.lstrip()
            if stripped.startswith("[") and not stripped.startswith("#"):
                skipping = False
            else:
                continue
        out.append(line)
    return "".join(out)


def cmd_merge_codex(args):
    dest = Path(args.dest)
    template = Path(args.template).read_text()
    header = "[model_providers.cpa]"
    provider = _section(template, header)
    if not provider.startswith(header):
        print("template is missing [model_providers.cpa]", file=sys.stderr)
        return 1
    dest.parent.mkdir(parents=True, exist_ok=True)
    if not dest.exists():
        if not template.endswith("\n"):
            template += "\n"
        dest.write_text(template)
        os.chmod(dest, 0o600)
        print("created")
        return 0

    original = dest.read_text()
    body = _without_section(original, header).rstrip() + "\n"
    if not re.search(r"(?m)^[ \t]*model_provider[ \t]*=", body):
        body = 'model_provider = "cpa"\n\n' + body.lstrip("\n")
    body = body.rstrip() + "\n\n" + provider
    if not body.endswith("\n"):
        body += "\n"
    if body == original:
        os.chmod(dest, 0o600)
        print("unchanged")
        return 0

    backup = dest.with_name(
        dest.name + ".dotfiles-backup." + time.strftime("%Y%m%d%H%M%S")
    )
    backup.write_text(original)
    os.chmod(backup, 0o600)
    dest.write_text(body)
    os.chmod(dest, 0o600)
    print("updated {0}".format(backup))
    return 0


def cmd_set_json(args):
    path = Path(args.path)
    path.parent.mkdir(parents=True, exist_ok=True)
    data = {}
    if path.exists() and path.read_text().strip():
        data = json.loads(path.read_text())
    if len(args.pairs) % 2 != 0:
        print("set-json needs key value pairs", file=sys.stderr)
        return 1
    values = iter(args.pairs)
    for key, value in zip(values, values):
        data[key] = value
    path.write_text(json.dumps(data, indent=2) + "\n")
    print("ok")
    return 0


def cmd_gnome_keybindings(args):
    raw = args.current.strip()
    if raw.startswith("@as"):
        raw = raw[3:].strip()
    if raw in ("", "[]"):
        items = []
    else:
        items = ast.literal_eval(raw)
    if args.path not in items:
        items.append(args.path)
    print("[" + ", ".join("'{0}'".format(item) for item in items) + "]")
    return 0


def cmd_set_default_browser(args):
    path = Path(args.path)
    path.parent.mkdir(parents=True, exist_ok=True)
    desktop = args.desktop
    keys = [
        "x-scheme-handler/http",
        "x-scheme-handler/https",
        "text/html",
        "application/xhtml+xml",
        "x-scheme-handler/about",
        "x-scheme-handler/unknown",
    ]
    lines = path.read_text().splitlines() if path.exists() else []
    section = "Default Applications"
    out = []
    in_section = False
    seen = set()
    found_section = False
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            if in_section:
                for key in keys:
                    if key not in seen:
                        out.append("{0}={1}".format(key, desktop))
                        seen.add(key)
            in_section = stripped[1:-1].strip() == section
            if in_section:
                found_section = True
            out.append(line)
            continue
        if in_section and "=" in line and not stripped.startswith("#"):
            key = line.split("=", 1)[0].strip()
            if key in keys:
                out.append("{0}={1}".format(key, desktop))
                seen.add(key)
                continue
        out.append(line)
    if in_section:
        for key in keys:
            if key not in seen:
                out.append("{0}={1}".format(key, desktop))
    if not found_section:
        if out and out[-1] != "":
            out.append("")
        out.append("[{0}]".format(section))
        for key in keys:
            out.append("{0}={1}".format(key, desktop))
    path.write_text("\n".join(out).rstrip() + "\n")
    print("ok")
    return 0


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)

    asset = sub.add_parser("github-asset")
    asset.add_argument("repo")
    asset.add_argument("regex")
    asset.set_defaults(func=cmd_github_asset)

    nightly = sub.add_parser("t3-nightly")
    nightly.add_argument("arch")
    nightly.set_defaults(func=cmd_t3_nightly)

    merge = sub.add_parser("merge-codex")
    merge.add_argument("dest")
    merge.add_argument("template")
    merge.set_defaults(func=cmd_merge_codex)

    setter = sub.add_parser("set-json")
    setter.add_argument("path")
    setter.add_argument("pairs", nargs="*")
    setter.set_defaults(func=cmd_set_json)

    keys = sub.add_parser("gnome-keybindings")
    keys.add_argument("current")
    keys.add_argument("path")
    keys.set_defaults(func=cmd_gnome_keybindings)

    browser = sub.add_parser("set-default-browser")
    browser.add_argument("path")
    browser.add_argument("desktop")
    browser.set_defaults(func=cmd_set_default_browser)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())

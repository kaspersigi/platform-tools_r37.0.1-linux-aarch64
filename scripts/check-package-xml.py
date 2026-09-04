#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0

from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ElementTree


def local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def direct_children(
    element: ElementTree.Element, name: str
) -> list[ElementTree.Element]:
    return [child for child in element if local_name(child.tag) == name]


def validate_package_xml(path: Path, version: str) -> list[str]:
    errors: list[str] = []
    if re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version) is None:
        return [f"invalid expected version: {version}"]
    expected_revision = version.split(".")

    try:
        root = ElementTree.parse(path).getroot()
    except (OSError, ElementTree.ParseError) as error:
        return [f"cannot parse {path}: {error}"]

    if local_name(root.tag) != "repository":
        errors.append("root element is not repository")
    packages = direct_children(root, "localPackage")
    if len(packages) != 1:
        errors.append(f"expected one localPackage, found {len(packages)}")
        return errors

    package = packages[0]
    if package.attrib.get("path") != "platform-tools":
        errors.append("localPackage path is not platform-tools")
    if package.attrib.get("obsolete") != "false":
        errors.append("localPackage obsolete is not false")

    revisions = direct_children(package, "revision")
    if len(revisions) != 1:
        errors.append(f"expected one revision, found {len(revisions)}")
    else:
        revision = revisions[0]
        actual_revision: list[str] = []
        for field in ("major", "minor", "micro"):
            children = direct_children(revision, field)
            if len(children) != 1 or children[0].text is None:
                errors.append(f"expected one non-empty revision {field}")
                actual_revision.append("")
            else:
                actual_revision.append(children[0].text.strip())
        if actual_revision != expected_revision:
            errors.append(
                "revision differs: "
                f"expected={version} actual={'.'.join(actual_revision)}"
            )

    display_names = direct_children(package, "display-name")
    expected_display_name = "Android SDK Platform-Tools Linux AArch64 community build"
    if (
        len(display_names) != 1
        or (display_names[0].text or "").strip() != expected_display_name
    ):
        errors.append("display-name differs from the Linux AArch64 package identity")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("package_xml", type=Path)
    parser.add_argument("version")
    args = parser.parse_args()
    errors = validate_package_xml(args.package_xml, args.version)
    for error in errors:
        print(f"error: {error}", file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())

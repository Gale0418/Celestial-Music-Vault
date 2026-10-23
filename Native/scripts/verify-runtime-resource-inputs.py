#!/usr/bin/env python3
"""Read-only CMV runtime resource/source contract guard.

This intentionally checks only the known CMV shader, asset catalog and signing
input contract. It never builds, writes, installs or changes project settings.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import plistlib
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

METAL_REL = Path("Native/CMV/CMV/SaturnAtmosphere.metal")
ENT_REL = Path("Native/CMV/CMV/CMV.entitlements")
CELESTIAL_REL = Path("Native/CMV/CMV/CelestialViews.swift")
PROJECT_REL = Path("Native/CMV/CMV.xcodeproj/project.pbxproj")
ASSETS_REL = Path("Native/CMV/CMV/Assets.xcassets")
SHADER_SYMBOL = "saturnScene"

# Xcode/Apple add a small, SDK-dependent set of signing metadata to the
# entitlements emitted into the final bundle.  These are deliberately listed
# here instead of accepting every ``com.apple.*`` key: a new capability must be
# added to the source contract before this guard will accept it.
AUTO_SIGNED_ENTITLEMENT_KEYS = {
    "ios": {
        "application-identifier",
        "beta-reports-active",
        "com.apple.developer.team-identifier",
        "get-task-allow",
    },
    "macos": {
        "com.apple.application-identifier",
        "com.apple.developer.team-identifier",
        "com.apple.security.get-task-allow",
    },
}
PROFILE_ONLY_ENTITLEMENT_KEYS = {"keychain-access-groups"}
EXPECTED_PROFILE_PLATFORMS = {"ios": "iOS", "macos": "OSX"}
EXPECTED_BUNDLE_PLATFORMS = {"ios": "iPhoneOS", "macos": "MacOSX"}
EXPECTED_APP_ID_KEY = {
    "ios": "application-identifier",
    "macos": "com.apple.application-identifier",
}
def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def file_record(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {"path": str(path), "exists": False, "bytes": None, "sha256": None}
    return {"path": str(path), "exists": True, "bytes": path.stat().st_size, "sha256": sha256(path)}


def load_plist(path: Path) -> Any:
    return plistlib.loads(path.read_bytes())


def plist_from_tool_output(payload: bytes) -> Any | None:
    """Decode the XML plist embedded in a tool's mixed stdout/stderr output."""
    starts = [i for i in (payload.find(b"<?xml"), payload.find(b"<plist")) if i >= 0]
    if not starts:
        return None
    begin = min(starts)
    end = payload.find(b"</plist>", begin)
    xml = payload[begin : end + len(b"</plist>")] if end >= 0 else payload[begin:]
    try:
        return plistlib.loads(xml)
    except Exception:
        return None


def profile_path(app: Path, platform: str) -> Path | None:
    candidates = (
        [app / "embedded.mobileprovision", app / "Contents/embedded.provisionprofile"]
        if platform == "ios"
        else [app / "Contents/embedded.provisionprofile", app / "embedded.mobileprovision"]
    )
    return next((candidate for candidate in candidates if candidate.is_file()), None)


def extract_profile_plist(path: Path) -> tuple[int, Any | None, str]:
    """Decode an embedded Apple profile without consulting a network service."""
    try:
        result = subprocess.run(
            ["security", "cms", "-D", "-i", str(path)],
            check=False,
            capture_output=True,
        )
    except OSError as exc:
        result = None
        detail = f"security cms unavailable: {exc}"
    else:
        decoded = plist_from_tool_output(result.stdout + b"\n" + result.stderr)
        if decoded is not None:
            return result.returncode, decoded, "embedded profile decoded"
        detail = (result.stdout + b"\n" + result.stderr).decode("utf-8", errors="replace")[-2000:]

    # Test fixtures and a few local signing tools expose the CMS payload as a
    # plain plist.  Accept that only as a decoding fallback; it remains an
    # independent profile input and is still checked below.
    try:
        return 0, load_plist(path), "embedded profile plist decoded"
    except Exception as exc:
        return result.returncode if result is not None else 127, None, f"profile decode failed: {detail}; {exc}"


def build_settings(project_text: str) -> dict[str, str]:
    settings: dict[str, str] = {}
    for match in re.finditer(r"(?m)^\s*(?:\"([^\"]+)\"|([A-Za-z0-9_]+))\s*=\s*([^;]+);", project_text):
        key = match.group(1) or match.group(2)
        value = match.group(3).strip()
        if len(value) >= 2 and value[0] == value[-1] == '"':
            value = value[1:-1]
        # The project file also contains a test target.  The first occurrence
        # of the app target's product settings is the source contract we need;
        # later test-target values must not silently overwrite it.
        settings.setdefault(key, value)
    return settings


def resolve_setting(value: str, settings: dict[str, str]) -> str:
    for _ in range(8):
        match = re.fullmatch(r"\$\(([^)]+)\)", value)
        if not match or match.group(1) not in settings:
            return value
        value = settings[match.group(1)]
    return value


def project_entitlement_scope(project_text: str) -> dict[str, Any]:
    """Read CODE_SIGN_ENTITLEMENTS SDK selectors without evaluating Xcode."""
    entries: list[dict[str, str]] = []
    pattern = re.compile(
        r"(?m)^\s*(?:\"(?P<quoted>CODE_SIGN_ENTITLEMENTS(?:\[sdk=[^\]]+\])?)\"|(?P<plain>CODE_SIGN_ENTITLEMENTS(?:\[sdk=[^\]]+\])?))\s*=\s*(?P<value>[^;]+);"
    )
    for match in pattern.finditer(project_text):
        key = match.group("quoted") or match.group("plain")
        value = match.group("value").strip().strip('"')
        sdk_match = re.search(r"\[sdk=([^\]]+)\]", key)
        entries.append({"key": key, "sdk": sdk_match.group(1).lower() if sdk_match else "*", "value": value})
    return {"entries": entries, "sdkNames": sorted({item["sdk"] for item in entries})}


def source_entitlement_scope(source_project_text: str, platform: str) -> dict[str, Any]:
    scope = project_entitlement_scope(source_project_text)
    entries = scope["entries"]
    expected_mac_value = "CMV/CMV.entitlements"
    errors: list[str] = []
    # This project intentionally has exactly one app-owned declaration.  A
    # generic key or any future/unknown SDK selector must be visible as a
    # contract drift instead of being silently ignored for either platform.
    mac_entries = [item for item in entries if item["sdk"] == "macosx*"]
    unexpected = [item for item in entries if item["sdk"] != "macosx*"]
    if unexpected:
        selectors = ", ".join(item["key"] for item in unexpected)
        errors.append("project has unexpected CODE_SIGN_ENTITLEMENTS selector(s): " + selectors)
    if not mac_entries:
        errors.append("project has no macOS CODE_SIGN_ENTITLEMENTS[sdk=macosx*] declaration")
    elif any(item["value"] != expected_mac_value for item in mac_entries):
        errors.append("macOS CODE_SIGN_ENTITLEMENTS points outside CMV.entitlements")
    selected = mac_entries if platform == "macos" else []
    return {"entries": entries, "selected": selected, "errors": errors, "platform": platform}


def expected_signed_entitlements(platform: str, source_values: dict[str, Any], profile_values: dict[str, Any] | None) -> dict[str, Any]:
    expected = dict(source_values)
    if profile_values:
        for key in AUTO_SIGNED_ENTITLEMENT_KEYS[platform]:
            if key in profile_values:
                expected[key] = profile_values[key]
    return expected


def scoped_entitlement_differences(
    platform: str,
    source_values: dict[str, Any],
    signed_values: dict[str, Any],
    profile_values: dict[str, Any] | None = None,
) -> dict[str, list[str]]:
    """Return strict SDK capability differences for tests and the CLI guard."""
    allowed_signed = set(source_values) | AUTO_SIGNED_ENTITLEMENT_KEYS[platform]
    result = {
        "extraSignedCapabilityKeys": sorted(set(signed_values) - allowed_signed),
        "missingSourceKeys": sorted(set(source_values) - set(signed_values)),
        "mismatchedSourceKeys": sorted(key for key in source_values if signed_values.get(key) != source_values[key]),
        "missingProfileAutomaticKeys": [],
        "profileAutomaticValueMismatches": [],
        "unprofiledAutomaticKeys": [],
    }
    if profile_values is not None:
        result["missingProfileAutomaticKeys"] = sorted(
            key for key in AUTO_SIGNED_ENTITLEMENT_KEYS[platform]
            if key in profile_values and key not in signed_values
        )
        result["profileAutomaticValueMismatches"] = sorted(
            key for key in AUTO_SIGNED_ENTITLEMENT_KEYS[platform]
            if key in signed_values and key in profile_values and signed_values[key] != profile_values[key]
        )
        # With an embedded profile, every automatic signing key present in the
        # signed blob must be granted by that profile.  There is no generic
        # omission exception here: the current Apple exports expose the exact
        # profile-derived set, while profile-absent development/ad-hoc paths
        # are handled separately as identity-unverified below.
        result["unprofiledAutomaticKeys"] = sorted(
            key for key in AUTO_SIGNED_ENTITLEMENT_KEYS[platform]
            if key in signed_values and key not in profile_values
        )
    return result


def profile_identity_differences(
    platform: str,
    profile_values: dict[str, Any],
    project_bundle: str,
    signed_values: dict[str, Any],
) -> list[str]:
    """Check profile-derived app/team identity independently of codesign."""
    app_key = EXPECTED_APP_ID_KEY[platform]
    profile_app_id = profile_values.get(app_key)
    profile_team = profile_values.get("com.apple.developer.team-identifier")
    mismatches: list[str] = []
    if not isinstance(profile_app_id, str) or not isinstance(profile_team, str):
        return [app_key, "com.apple.developer.team-identifier"]
    if profile_app_id != f"{profile_team}.{project_bundle}":
        mismatches.append("profile:" + app_key)
    if signed_values.get(app_key) != profile_app_id:
        mismatches.append(app_key)
    if signed_values.get("com.apple.developer.team-identifier") != profile_team:
        mismatches.append("com.apple.developer.team-identifier")
    return mismatches


def pinned_external_entitlements_match(
    expected: Any,
    decoded: Any,
    expected_sha: str,
    pinned_sha: str | None,
    codesign_exit: int,
) -> dict[str, bool]:
    """Keep the legacy external plist SHA + exact dictionary contract testable."""
    return {
        "shaPinnedExact": bool(pinned_sha) and expected_sha == pinned_sha,
        "decodedExact": decoded == expected,
        "codesignSuccess": codesign_exit == 0,
    }


def extract_codesign_plist(app: Path) -> tuple[int, Any | None, str]:
    try:
        result = subprocess.run(
            ["codesign", "-d", "--entitlements", ":-", str(app)],
            check=False,
            capture_output=True,
        )
    except OSError as exc:
        return 127, None, f"codesign unavailable: {exc}"
    payload = result.stdout + b"\n" + result.stderr
    starts = [i for i in (payload.find(b"<?xml"), payload.find(b"<plist")) if i >= 0]
    if not starts:
        return result.returncode, None, payload.decode("utf-8", errors="replace")[-2000:]
    begin = min(starts)
    end = payload.find(b"</plist>", begin)
    xml = payload[begin : end + len(b"</plist>")] if end >= 0 else payload[begin:]
    try:
        decoded = plistlib.loads(xml)
    except Exception as exc:  # malformed tool output is a diagnostic failure
        return result.returncode, None, f"plist decode failed: {exc}"
    return result.returncode, decoded, "codesign entitlements decoded"


def app_metallib(app: Path, platform: str) -> Path | None:
    candidates = (
        [app / "Contents/Resources/default.metallib", app / "default.metallib"]
        if platform == "macos"
        else [app / "default.metallib", app / "Contents/Resources/default.metallib"]
    )
    return next((candidate for candidate in candidates if candidate.is_file()), None)


def asset_catalog_records(assets_root: Path) -> tuple[set[str], list[dict[str, Any]], list[str]]:
    names: set[str] = set()
    files: list[dict[str, Any]] = []
    errors: list[str] = []
    if not assets_root.is_dir():
        return names, files, [f"asset catalog missing: {assets_root}"]
    for contents in sorted(assets_root.rglob("Contents.json")):
        rel = contents.parent.relative_to(assets_root)
        names.add(rel.name.removesuffix(".imageset").removesuffix(".appiconset"))
        try:
            payload = json.loads(contents.read_text(encoding="utf-8"))
        except Exception as exc:
            errors.append(f"{contents}: JSON decode failed: {exc}")
            continue
        for image in payload.get("images", []):
            filename = image.get("filename")
            if not filename:
                continue
            file_path = contents.parent / filename
            record = {
                "catalog": str(contents),
                "filename": filename,
                "path": str(file_path),
                "exists": file_path.is_file(),
                "bytes": file_path.stat().st_size if file_path.is_file() else None,
            }
            files.append(record)
            if not file_path.is_file():
                errors.append(f"asset filename missing: {file_path}")
            names.add(Path(filename).stem)
    return names, files, errors


def dynamic_background_asset_map(source_text: str) -> dict[str, str]:
    """Extract the explicit CMVThemeID -> catalog-name mapping.

    This is intentionally narrow: it only accepts string literals in the
    backgroundAssetName switch, so a future computed name remains visible as
    an unsupported source contract instead of being silently accepted.
    """
    marker = re.search(r"private\s+var\s+backgroundAssetName\s*:\s*String\s*\{", source_text)
    if not marker:
        return {}
    switch_start = source_text.find("switch theme.id", marker.end())
    if switch_start < 0:
        return {}
    switch_text = source_text[switch_start : source_text.find("\n    }", switch_start)]
    mapping = {
        theme: asset
        for theme, asset in re.findall(r"case\s+\.([A-Za-z0-9_]+)\s*:\s*\"([^\"]+)\"", switch_text)
    }
    declared_cases = re.findall(r"case\s+\.([A-Za-z0-9_]+)", switch_text)
    if len(declared_cases) != len(mapping) or set(declared_cases) != set(mapping):
        return {}
    return mapping


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", required=True, type=Path)
    parser.add_argument("--workspace-root", required=True, type=Path)
    parser.add_argument("--app", type=Path)
    parser.add_argument("--platform", required=True, choices=("ios", "macos"))
    parser.add_argument("--expected-entitlements", type=Path)
    parser.add_argument("--expected-entitlements-sha")
    args = parser.parse_args()

    source = args.source_root.resolve()
    workspace = args.workspace_root.resolve()
    report: dict[str, Any] = {
        "schema": "cmv.verify-runtime-resource-inputs.v1",
        "mode": "read-only",
        "platform": args.platform,
        "sourceRoot": str(source),
        "workspaceRoot": str(workspace),
        "app": str(args.app.resolve()) if args.app else None,
        "checks": {},
        "errors": [],
        "warnings": [],
    }

    def add_error(message: str) -> None:
        report["errors"].append(message)

    # Fixed, auditable source inputs only.
    source_metal = source / METAL_REL
    workspace_metal = workspace / METAL_REL
    source_ent = source / ENT_REL
    workspace_ent = workspace / ENT_REL
    source_celestial = source / CELESTIAL_REL
    source_project = source / PROJECT_REL
    workspace_project = workspace / PROJECT_REL
    source_info = source / "Native/CMV/CMV/Info.plist"

    source_inputs = {
        "metal": file_record(source_metal),
        "entitlements": file_record(source_ent),
        "celestialViews": file_record(source_celestial),
        "project": file_record(source_project),
        "info": file_record(source_info),
    }
    report["checks"]["sourceInputs"] = source_inputs
    for key in ("metal", "celestialViews", "project", "info"):
        if not source_inputs[key]["exists"]:
            add_error(f"missing required source input: {key}")

    source_sha_check: dict[str, Any] = {}
    for label, source_path, workspace_path in (
        ("metal", source_metal, workspace_metal),
        ("entitlements", source_ent, workspace_ent),
    ):
        item = {
            "source": file_record(source_path),
            "workspace": file_record(workspace_path),
            "shaExact": False,
        }
        if source_path.is_file() and workspace_path.is_file():
            item["shaExact"] = sha256(source_path) == sha256(workspace_path)
            if not item["shaExact"]:
                add_error(f"source/workspace SHA differs: {label}")
        source_sha_check[label] = item
    report["checks"]["sourceSHA"] = source_sha_check

    project_text = source_project.read_text(encoding="utf-8", errors="replace") if source_project.is_file() else ""
    sync_group = "fileSystemSynchronizedGroups" in project_text
    report["checks"]["fileSystemSynchronizedGroups"] = sync_group
    if not sync_group:
        add_error("CMV project has no fileSystemSynchronizedGroups marker")

    signing_scope = source_entitlement_scope(project_text, args.platform)
    report["checks"]["signingScope"] = signing_scope
    for error in signing_scope["errors"]:
        add_error(error)

    source_info_values: dict[str, Any] = {}
    if source_info.is_file():
        try:
            source_info_values = load_plist(source_info)
            if not isinstance(source_info_values, dict):
                raise ValueError("Info.plist root is not a dictionary")
        except Exception as exc:
            add_error(f"source Info.plist decode failed: {exc}")
            source_info_values = {}
    settings = build_settings(project_text)
    project_bundle = resolve_setting(settings.get("PRODUCT_BUNDLE_IDENTIFIER", ""), settings)
    report["checks"]["sourceBundleContract"] = {
        "projectBundleIdentifier": project_bundle,
        "sourceInfoBundleIdentifier": source_info_values.get("CFBundleIdentifier"),
        "sourceInfoPlatform": EXPECTED_BUNDLE_PLATFORMS[args.platform],
    }
    if source_info_values.get("CFBundleIdentifier") != "$(PRODUCT_BUNDLE_IDENTIFIER)":
        add_error("source Info.plist CFBundleIdentifier is not project-resolved")
    if not project_bundle or "$" in project_bundle:
        add_error("project PRODUCT_BUNDLE_IDENTIFIER is not independently resolvable")

    celestial_text = source_celestial.read_text(encoding="utf-8", errors="replace") if source_celestial.is_file() else ""
    metal_text = source_metal.read_text(encoding="utf-8", errors="replace") if source_metal.is_file() else ""
    shader_call = bool(re.search(r"ShaderLibrary\.saturnScene\b", celestial_text))
    shader_definition = bool(re.search(r"\[\[\s*stitchable\s*\]\][\s\S]{0,160}\bhalf4\s+saturnScene\s*\(", metal_text))
    report["checks"]["shaderContract"] = {
        "shaderLibraryCall": shader_call,
        "metalStitchableDefinition": shader_definition,
        "symbol": SHADER_SYMBOL,
    }
    if not shader_call:
        add_error("CelestialViews.swift has no ShaderLibrary.saturnScene call")
    if not shader_definition:
        add_error("SaturnAtmosphere.metal has no stitchable saturnScene definition")

    # Literal Image("...") references and the explicit dynamic background switch
    # are checked separately. The latter closes the historical guard blind spot
    # without attempting to evaluate arbitrary Swift expressions.
    image_refs = sorted(set(re.findall(r"\bImage\(\s*\"([^\"]+)\"\s*\)", celestial_text)))
    known_assets, catalog_files, catalog_errors = asset_catalog_records(source / ASSETS_REL)
    missing_assets = [name for name in image_refs if name not in known_assets]
    report["checks"]["assetReferences"] = {
        "literalImageReferences": image_refs,
        "knownAssetNames": sorted(known_assets),
        "missingReferences": missing_assets,
        "catalogFiles": catalog_files,
        "catalogErrors": catalog_errors,
    }
    if missing_assets:
        add_error("missing asset catalog names: " + ", ".join(missing_assets))
    dynamic_map = dynamic_background_asset_map(celestial_text)
    dynamic_names = sorted(set(dynamic_map.values()))
    missing_dynamic = [name for name in dynamic_names if name not in known_assets]
    report["checks"]["dynamicAssetReferences"] = {
        "sourceContract": "backgroundAssetName switch",
        "themeToAsset": dynamic_map,
        "dynamicAssetNames": dynamic_names,
        "missingReferences": missing_dynamic,
        "supportedOnlyWhenLiteral": True,
    }
    if not dynamic_map:
        add_error("CelestialViews.swift has no supported backgroundAssetName switch")
    if missing_dynamic:
        add_error("missing dynamic asset catalog names: " + ", ".join(missing_dynamic))
    for error in catalog_errors:
        add_error(error)

    # App-level checks are deliberately incomplete without --app.
    app = args.app.resolve() if args.app else None
    if app is None:
        report["checks"]["appRuntime"] = {"provided": False, "status": "APP_REQUIRED"}
        report["checks"]["entitlements"] = {"provided": False, "status": "APP_REQUIRED"}
        report["status"] = "FAIL_SOURCE_INPUTS_APP_UNVERIFIED" if report["errors"] else "INCOMPLETE_APP_REQUIRED"
    else:
        if not app.is_dir():
            add_error(f"app path is not a directory: {app}")
        metallib = app_metallib(app, args.platform)
        metal_check: dict[str, Any] = {"provided": True, "path": str(metallib) if metallib else None}
        if metallib is None:
            metal_check.update({"exists": False, "bytes": None, "nonzero": False, "symbolPresent": False})
            add_error("default.metallib missing from app bundle")
        else:
            payload = metallib.read_bytes()
            symbol_present = SHADER_SYMBOL.encode("ascii") in payload
            if not symbol_present:
                try:
                    strings = subprocess.run(["strings", str(metallib)], check=False, capture_output=True, text=True).stdout
                    symbol_present = SHADER_SYMBOL in strings
                except OSError:
                    pass
            metal_check.update({"exists": True, "bytes": len(payload), "sha256": sha256(metallib), "nonzero": bool(payload), "symbolPresent": symbol_present})
            if not payload or not symbol_present:
                add_error("default.metallib must be nonzero and expose saturnScene symbol")
        report["checks"]["appRuntime"] = metal_check

        # The macOS plist is an SDK-scoped source capability input.  iOS has no
        # app-owned plist in this project; its automatic signing keys must be
        # justified by the independent bundle Info and embedded profile.
        source_declared = args.platform == "macos" and source_ent.is_file() and bool(signing_scope["selected"])
        ent_source = source_ent if source_declared else args.expected_entitlements.resolve() if not source_ent.is_file() and args.expected_entitlements else None
        ent_check: dict[str, Any] = {
            "sourceInput": file_record(source_ent),
            "externalInput": file_record(args.expected_entitlements.resolve()) if args.expected_entitlements else None,
            "inputMode": "source" if source_declared else "sdk-independent" if args.platform == "ios" and source_ent.is_file() else "external" if args.expected_entitlements else "none",
            "sourceScopedToSDK": source_declared,
        }
        rc, decoded, detail = extract_codesign_plist(app)
        ent_check["codesignExit"] = rc
        ent_check["codesignDetail"] = detail
        ent_check["decodedKeys"] = sorted(decoded.keys()) if isinstance(decoded, dict) else []

        # Preserve the old externally pinned contract byte-for-byte: an
        # explicitly external plist still requires its SHA and exact codesign
        # dictionary match.  Independent profile checks below still run.
        using_external = ent_source is not None and not source_declared
        if using_external:
            try:
                expected_external = load_plist(ent_source)
                expected_sha = sha256(ent_source)
                ent_check["expectedSHA256"] = expected_sha
                pinned = pinned_external_entitlements_match(
                    expected_external,
                    decoded,
                    expected_sha,
                    args.expected_entitlements_sha,
                    rc,
                )
                ent_check.update(pinned)
                if not args.expected_entitlements_sha:
                    add_error("external entitlements requires --expected-entitlements-sha")
                elif not ent_check["shaPinnedExact"]:
                    add_error("external entitlements SHA does not match --expected-entitlements-sha")
                if not ent_check["decodedExact"]:
                    add_error("decoded codesign entitlements do not exactly match declared external input")
                ent_check["status"] = "PASS_PINNED_EXTERNAL_ENTITLEMENTS" if ent_check["shaPinnedExact"] and ent_check["decodedExact"] and rc == 0 else "ENTITLEMENTS_MISMATCH"
            except Exception as exc:
                ent_check["status"] = "ENTITLEMENTS_DECODE_ERROR"
                ent_check["error"] = str(exc)
                add_error(f"external entitlements decode failed: {exc}")
        else:
            ent_check["status"] = "PENDING_SDK_PROFILE_CHECK"

        # Independent source/project/Info/profile contract.  No expected value
        # is copied from codesign output: profile identity and project bundle
        # settings provide the expected application and team identifiers.
        app_info_path = app / "Info.plist" if args.platform == "ios" else app / "Contents/Info.plist"
        profile = profile_path(app, args.platform)
        profile_check: dict[str, Any] = {
            "path": str(profile) if profile else None,
            "provided": profile is not None,
            "platform": args.platform,
        }
        app_info: dict[str, Any] = {}
        if not app_info_path.is_file():
            add_error(f"app Info.plist missing: {app_info_path}")
        else:
            try:
                app_info = load_plist(app_info_path)
                supported = app_info.get("CFBundleSupportedPlatforms", []) if isinstance(app_info, dict) else []
                if EXPECTED_BUNDLE_PLATFORMS[args.platform] not in supported:
                    add_error(f"app Info.plist platform does not match --platform {args.platform}")
                if app_info.get("CFBundleIdentifier") != project_bundle:
                    add_error("app Info.plist bundle identifier differs from project source")
            except Exception as exc:
                add_error(f"app Info.plist decode failed: {exc}")
        report["checks"]["appInfoContract"] = {
            "path": str(app_info_path),
            "bundleIdentifier": app_info.get("CFBundleIdentifier"),
            "supportedPlatforms": app_info.get("CFBundleSupportedPlatforms"),
            "projectBundleIdentifier": project_bundle,
        }

        profile_values: dict[str, Any] = {}
        if profile is None:
            profile_check["status"] = "PROFILE_UNAVAILABLE"
            # Existing ad-hoc/development callers may have no embedded profile;
            # source-scoped validation remains active, but no Apple identity is
            # invented from codesign output.
            source_values: dict[str, Any] = {}
            if source_declared:
                try:
                    source_values = load_plist(source_ent)
                    if not isinstance(source_values, dict):
                        raise ValueError("source entitlements root is not a dictionary")
                except Exception as exc:
                    add_error(f"source entitlements decode failed: {exc}")
            signed_values = decoded if isinstance(decoded, dict) else {}
            differences = scoped_entitlement_differences(args.platform, source_values, signed_values)
            extra_signed = differences["extraSignedCapabilityKeys"]
            missing_source = differences["missingSourceKeys"]
            mismatched_source = differences["mismatchedSourceKeys"]
            ent_check.update({
                "sourceValues": source_values,
                "extraSignedCapabilityKeys": extra_signed,
                "missingSourceKeys": missing_source,
                "mismatchedSourceKeys": mismatched_source,
            })
            if extra_signed:
                add_error("signed entitlements contain unknown/extra capability keys: " + ", ".join(extra_signed))
            if missing_source or mismatched_source:
                add_error("signed entitlements do not match source-declared SDK capabilities")
            if not signed_values or rc != 0:
                add_error("codesign entitlements could not be decoded for SDK-scoped validation")
            ent_check["identityStatus"] = "SCOPED_CAPABILITIES_IDENTITY_UNVERIFIED"
            report["warnings"].append("embedded profile unavailable; Apple signing identity remains unverified")
            if ent_check.get("status") == "PENDING_SDK_PROFILE_CHECK":
                ent_check["status"] = "SCOPED_CAPABILITIES_IDENTITY_UNVERIFIED" if not report["errors"] else "ENTITLEMENTS_CONTRACT_FAILED"
        else:
            profile_rc, profile_decoded, profile_detail = extract_profile_plist(profile)
            profile_check.update({"decodeExit": profile_rc, "decodeDetail": profile_detail})
            if not isinstance(profile_decoded, dict):
                profile_check["status"] = "PROFILE_DECODE_ERROR"
                add_error("embedded provisioning profile could not be decoded")
            else:
                profile_platforms = profile_decoded.get("Platform", [])
                profile_values = profile_decoded.get("Entitlements", {})
                if not isinstance(profile_values, dict):
                    profile_values = {}
                    add_error("embedded provisioning profile Entitlements is not a dictionary")
                profile_check.update({
                    "profileName": profile_decoded.get("Name"),
                    "profileUUID": profile_decoded.get("UUID"),
                    "profilePlatforms": profile_platforms,
                    "entitlementKeys": sorted(profile_values),
                })
                if EXPECTED_PROFILE_PLATFORMS[args.platform] not in profile_platforms:
                    add_error(f"embedded profile platform does not match --platform {args.platform}")
                profile_allowed = AUTO_SIGNED_ENTITLEMENT_KEYS[args.platform] | PROFILE_ONLY_ENTITLEMENT_KEYS
                unknown_profile = sorted(set(profile_values) - profile_allowed)
                profile_check["unknownEntitlementKeys"] = unknown_profile
                if unknown_profile:
                    add_error("embedded profile contains unknown capability keys: " + ", ".join(unknown_profile))
                expected_app_key = EXPECTED_APP_ID_KEY[args.platform]
                profile_app_id = profile_values.get(expected_app_key)
                profile_team = profile_values.get("com.apple.developer.team-identifier")
                if not isinstance(profile_app_id, str) or not isinstance(profile_team, str):
                    add_error("embedded profile is missing the SDK-specific application/team identity")
                else:
                    expected_app_id = f"{profile_team}.{project_bundle}"
                    if profile_app_id != expected_app_id:
                        add_error("embedded profile application identifier differs from profile team/project bundle")
                    prefix = profile_decoded.get("ApplicationIdentifierPrefix", [])
                    if prefix and profile_team not in prefix:
                        add_error("embedded profile team is outside ApplicationIdentifierPrefix")

                source_values: dict[str, Any] = {}
                if source_declared:
                    try:
                        source_values = load_plist(source_ent)
                        if not isinstance(source_values, dict):
                            raise ValueError("source entitlements root is not a dictionary")
                    except Exception as exc:
                        source_values = {}
                        add_error(f"source entitlements decode failed: {exc}")
                signed_values = decoded if isinstance(decoded, dict) else {}
                expected_values = expected_signed_entitlements(args.platform, source_values, profile_values)
                differences = scoped_entitlement_differences(args.platform, source_values, signed_values, profile_values)
                extra_signed = differences["extraSignedCapabilityKeys"]
                missing_source = differences["missingSourceKeys"]
                mismatched_source = differences["mismatchedSourceKeys"]
                missing_profile_auto = differences["missingProfileAutomaticKeys"]
                profile_value_mismatches = differences["profileAutomaticValueMismatches"]
                unprofiled_auto = differences["unprofiledAutomaticKeys"]
                identity_mismatches = profile_identity_differences(args.platform, profile_values, project_bundle, signed_values)
                ent_check.update({
                    "sourceValues": source_values,
                    "profileAutoValues": {key: profile_values[key] for key in sorted(AUTO_SIGNED_ENTITLEMENT_KEYS[args.platform]) if key in profile_values},
                    "expectedSignedKeys": sorted(expected_values),
                    "extraSignedCapabilityKeys": extra_signed,
                    "missingSourceKeys": missing_source,
                    "mismatchedSourceKeys": mismatched_source,
                    "missingProfileAutomaticKeys": missing_profile_auto,
                    "profileAutomaticValueMismatches": profile_value_mismatches,
                    "unprofiledAutomaticKeys": unprofiled_auto,
                    "identityMismatches": sorted(set(identity_mismatches)),
                })
                if extra_signed:
                    add_error("signed entitlements contain unknown/extra capability keys: " + ", ".join(extra_signed))
                if missing_source or mismatched_source:
                    add_error("signed entitlements do not match source-declared SDK capabilities")
                if missing_profile_auto:
                    add_error("signed entitlements omit automatic keys granted by the embedded profile: " + ", ".join(missing_profile_auto))
                if unprofiled_auto:
                    add_error("signed entitlements contain automatic keys not granted by the embedded profile: " + ", ".join(unprofiled_auto))
                if profile_value_mismatches or identity_mismatches:
                    add_error("signed automatic entitlements do not match independent profile identity/values")
                if not signed_values or rc != 0:
                    add_error("codesign entitlements could not be decoded for SDK-scoped validation")
                profile_check["status"] = "PASS_PROFILE_SOURCE_INFO_CONTRACT" if not report["errors"] else "PROFILE_CONTRACT_FAILED"
                ent_check["status"] = "PASS_SDK_SCOPED_ENTITLEMENTS" if not report["errors"] else "ENTITLEMENTS_CONTRACT_FAILED"
        report["checks"]["profileContract"] = profile_check
        report["checks"]["entitlements"] = ent_check
        report["status"] = "PASS_SCOPED_RUNTIME_RESOURCE_INPUTS" if not report["errors"] else "FAIL_RUNTIME_RESOURCE_INPUTS"

    print(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True))
    return 0 if report["status"] == "PASS_SCOPED_RUNTIME_RESOURCE_INPUTS" else 1


if __name__ == "__main__":
    sys.exit(main())

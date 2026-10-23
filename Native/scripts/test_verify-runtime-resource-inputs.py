#!/usr/bin/env python3
"""Focused, read-only tests for the SDK-scoped runtime resource guard."""
from __future__ import annotations

import importlib.util
import contextlib
import io
import json
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
GUARD_PATH = Path(__file__).with_name("verify-runtime-resource-inputs.py")
SPEC = importlib.util.spec_from_file_location("cmv_resource_guard", GUARD_PATH)
assert SPEC and SPEC.loader
GUARD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GUARD)


class SDKScopedGuardTests(unittest.TestCase):
    @staticmethod
    def _replace_macos_entitlement(project: str, replacement: str) -> str:
        return re.sub(
            r'(?m)^\s*"?CODE_SIGN_ENTITLEMENTS\[sdk=macosx\*\]"?\s*=\s*"?CMV/CMV\.entitlements"?;',
            replacement,
            project,
            count=1,
        )

    def test_project_scope_rejects_wrong_platform_source(self) -> None:
        project = (ROOT / "Native/CMV/CMV.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
        self.assertEqual(GUARD.source_entitlement_scope(project, "ios")["errors"], [])
        wrong = self._replace_macos_entitlement(
            project,
            'CODE_SIGN_ENTITLEMENTS[sdk=macosx*] = CMV/CMV.entitlements;\n'
            'CODE_SIGN_ENTITLEMENTS[sdk=iphoneos*] = CMV/CMV.entitlements;',
        )
        self.assertTrue(GUARD.source_entitlement_scope(wrong, "ios")["errors"])

    def test_project_scope_rejects_generic_and_unknown_selectors(self) -> None:
        project = (ROOT / "Native/CMV/CMV.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
        generic = self._replace_macos_entitlement(project, "CODE_SIGN_ENTITLEMENTS = CMV/CMV.entitlements;")
        unknown = self._replace_macos_entitlement(
            project,
            'CODE_SIGN_ENTITLEMENTS[sdk=futureosx*] = CMV/CMV.entitlements;',
        )
        self.assertTrue(GUARD.source_entitlement_scope(generic, "macos")["errors"])
        self.assertTrue(GUARD.source_entitlement_scope(generic, "ios")["errors"])
        self.assertTrue(GUARD.source_entitlement_scope(unknown, "macos")["errors"])

    def test_missing_and_extra_capability_fail(self) -> None:
        source = {
            "com.apple.security.app-sandbox": True,
            "com.apple.security.network.client": True,
        }
        profile = {
            "com.apple.application-identifier": "TEAM.com.windsheep.cmv",
            "com.apple.developer.team-identifier": "TEAM",
        }
        missing = GUARD.scoped_entitlement_differences("macos", source, dict(profile), profile)
        self.assertEqual(missing["missingSourceKeys"], sorted(source))
        signed = dict(source)
        signed.update(profile)
        signed["com.apple.security.unknown"] = True
        extra = GUARD.scoped_entitlement_differences("macos", source, signed, profile)
        self.assertEqual(extra["extraSignedCapabilityKeys"], ["com.apple.security.unknown"])

    def test_automatic_key_not_granted_by_profile_fails(self) -> None:
        profile = {
            "com.apple.application-identifier": "TEAM.com.windsheep.cmv",
            "com.apple.developer.team-identifier": "TEAM",
        }
        signed = dict(profile)
        signed["com.apple.security.get-task-allow"] = True
        differences = GUARD.scoped_entitlement_differences("macos", {}, signed, profile)
        self.assertEqual(differences["unprofiledAutomaticKeys"], ["com.apple.security.get-task-allow"])

    def test_bad_team_and_app_id_fail_independently(self) -> None:
        profile = {
            "application-identifier": "TEAM.com.windsheep.cmv",
            "com.apple.developer.team-identifier": "TEAM",
        }
        signed = dict(profile)
        signed["com.apple.developer.team-identifier"] = "OTHER"
        self.assertTrue(GUARD.profile_identity_differences("ios", profile, "com.windsheep.cmv", signed))
        bad_profile = dict(profile)
        bad_profile["application-identifier"] = "TEAM.other.bundle"
        self.assertIn(
            "profile:application-identifier",
            GUARD.profile_identity_differences("ios", bad_profile, "com.windsheep.cmv", signed),
        )

    def test_declared_scope_difference_is_rejected(self) -> None:
        project = (ROOT / "Native/CMV/CMV.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
        changed = self._replace_macos_entitlement(
            project,
            'CODE_SIGN_ENTITLEMENTS[sdk=macosx*] = Other/entitlements.plist;',
        )
        self.assertTrue(GUARD.source_entitlement_scope(changed, "macos")["errors"])

    def test_external_entitlements_requires_correct_pinned_sha(self) -> None:
        expected = {"com.apple.security.app-sandbox": True}
        correct = GUARD.pinned_external_entitlements_match(expected, expected, "sha-ok", "sha-ok", 0)
        wrong = GUARD.pinned_external_entitlements_match(expected, expected, "sha-ok", "sha-wrong", 0)
        self.assertTrue(correct["shaPinnedExact"] and correct["decodedExact"])
        self.assertFalse(wrong["shaPinnedExact"])


class CurrentExportsTests(unittest.TestCase):
    def _run(self, platform: str, app: Path) -> dict:
        command = [
            "python3",
            str(GUARD_PATH),
            "--source-root",
            str(ROOT),
            "--workspace-root",
            str(ROOT),
            "--platform",
            platform,
            "--app",
            str(app),
        ]
        result = subprocess.run(command, check=False, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return json.loads(result.stdout)

    def test_current_ios_and_macos_exports_pass(self) -> None:
        ios = Path("/tmp/cmv-task-zero-20261009-afternoon/current-release-prepare/ios/inspect-v1/Payload/CMV.app")
        mac = Path("/tmp/cmv-task-zero-20261009-afternoon/current-release-prepare/mac/inspect-v3/payload-root/CMV.app")
        if not ios.is_dir() or not mac.is_dir():
            self.skipTest("current release exports are not present in this checkout")
        for platform, app in (("ios", ios), ("macos", mac)):
            report = self._run(platform, app)
            self.assertEqual(report["status"], "PASS_SCOPED_RUNTIME_RESOURCE_INPUTS")
            self.assertEqual(report["errors"], [])

    def test_missing_profile_is_explicitly_unverified(self) -> None:
        app = Path("/tmp/cmv-task-zero-20261009-afternoon/current-release-prepare/mac/inspect-v3/payload-root/CMV.app")
        if not app.is_dir():
            self.skipTest("current macOS export is not present in this checkout")
        with tempfile.TemporaryDirectory(prefix="cmv-resource-guard-") as scratch:
            copied = Path(scratch) / "CMV.app"
            shutil.copytree(app, copied)
            (copied / "Contents/embedded.provisionprofile").unlink()
            report = self._run("macos", copied)
            self.assertEqual(report["status"], "PASS_SCOPED_RUNTIME_RESOURCE_INPUTS")
            self.assertEqual(report["checks"]["entitlements"]["status"], "SCOPED_CAPABILITIES_IDENTITY_UNVERIFIED")
            self.assertEqual(report["checks"]["profileContract"]["status"], "PROFILE_UNAVAILABLE")

    def test_profile_present_invalid_source_entitlements_still_emit_json_report(self) -> None:
        with tempfile.TemporaryDirectory(prefix="cmv-resource-profile-") as scratch:
            app = Path(scratch) / "CMV.app"
            contents = app / "Contents"
            contents.mkdir(parents=True)
            (contents / "default.metallib").write_bytes(b"saturnScene")
            (contents / "Info.plist").write_bytes(plistlib.dumps({
                "CFBundleIdentifier": "com.windsheep.cmv",
                "CFBundleSupportedPlatforms": ["MacOSX"],
            }))
            (contents / "embedded.provisionprofile").write_bytes(plistlib.dumps({
                "Name": "fixture-profile",
                "UUID": "fixture-uuid",
                "Platform": ["OSX"],
                "ApplicationIdentifierPrefix": ["TEAM"],
                "Entitlements": {
                    "com.apple.application-identifier": "TEAM.com.windsheep.cmv",
                    "com.apple.developer.team-identifier": "TEAM",
                },
            }))

            source_entitlements = ROOT / "Native/CMV/CMV/CMV.entitlements"
            original_load_plist = GUARD.load_plist

            def load_plist_with_broken_source(path: Path):
                if path.resolve() == source_entitlements.resolve():
                    raise ValueError("fixture source entitlements is malformed")
                return original_load_plist(path)

            stdout = io.StringIO()
            argv = [
                str(GUARD_PATH),
                "--source-root", str(ROOT),
                "--workspace-root", str(ROOT),
                "--platform", "macos",
                "--app", str(app),
            ]
            with (
                mock.patch.object(GUARD, "load_plist", side_effect=load_plist_with_broken_source),
                mock.patch.object(GUARD, "extract_codesign_plist", return_value=(0, {}, "fixture codesign")),
                mock.patch.object(sys, "argv", argv),
                contextlib.redirect_stdout(stdout),
            ):
                return_code = GUARD.main()

            report = json.loads(stdout.getvalue())
            self.assertEqual(return_code, 1)
            self.assertEqual(report["status"], "FAIL_RUNTIME_RESOURCE_INPUTS")
            self.assertEqual(report["checks"]["entitlements"]["sourceValues"], {})
            self.assertTrue(any(
                "source entitlements decode failed" in error
                for error in report["errors"]
            ))


if __name__ == "__main__":
    unittest.main(verbosity=2)

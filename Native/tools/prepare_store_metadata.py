#!/usr/bin/env python3
"""將版本化三語 Markdown 欄位轉為 asc 可驗證的 .strings。"""

import argparse
import json
from pathlib import Path
import re
import textwrap


FIELD_NAMES = {
    "name": ("Name", "名稱", "名前"),
    "subtitle": ("Subtitle", "副標題", "サブタイトル"),
    "keywords": ("Keywords", "關鍵字", "キーワード"),
    "promotionalText": ("Promotional text", "宣傳文字", "プロモーションテキスト"),
    "description": ("Description", "描述", "説明"),
    "whatsNew": ("What’s New", "最新消息", "新機能"),
    "privacyPolicyUrl": ("Privacy Policy URL", "隱私權政策 URL", "プライバシーポリシー URL"),
    "supportUrl": ("Support URL", "支援 URL", "サポート URL"),
}
LIMITS = {"name": 30, "subtitle": 30, "keywords": 100,
          "promotionalText": 170, "description": 4000, "whatsNew": 4000}
APP_INFO_FIELDS = {"name", "subtitle", "privacyPolicyUrl"}


def fields_from_markdown(path: Path) -> dict[str, str]:
    # Review contact and copyright runtime placeholders are deliberately excluded.
    store_section = path.read_text(encoding="utf-8").split("## App Review", 1)[0]
    matches = list(re.finditer(r"^- \*\*(.+?)[:：]\*\*(.*)$", store_section, re.M))
    parsed = {}
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(store_section)
        value = match.group(2).strip()
        if not value:
            value = textwrap.dedent(store_section[match.end():end]).strip()
        parsed[match.group(1)] = value
    fields = {}
    for field, names in FIELD_NAMES.items():
        value = next((parsed[name] for name in names if name in parsed), None)
        if not value or "RUNTIME_REQUIRED" in value:
            raise ValueError(f"{path.name}: 缺少可發布欄位 {field}")
        if field in LIMITS and len(value) > LIMITS[field]:
            raise ValueError(f"{path.name}: {field} 超過 {LIMITS[field]} 字元")
        fields[field] = value
    return fields


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1] / "AppStoreMetadata"
    for source_locale, asc_locale in (("en-US", "en-US"), ("zh-Hant", "zh-Hant"), ("ja-JP", "ja")):
        fields = fields_from_markdown(source / f"{source_locale}.md")
        for kind, chosen in (("app-info", APP_INFO_FIELDS),
                             ("version", set(FIELD_NAMES) - APP_INFO_FIELDS)):
            destination = args.output / kind / f"{asc_locale}.strings"
            destination.parent.mkdir(parents=True, exist_ok=True)
            lines = [f'{json.dumps(key)} = {json.dumps(fields[key], ensure_ascii=False)};'
                     for key in sorted(chosen)]
            destination.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"{asc_locale}: 必填文字與長度檢查通過")


if __name__ == "__main__":
    main()

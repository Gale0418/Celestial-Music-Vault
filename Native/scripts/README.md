# Native scripts

`qualify-app-store.sh` 是 CMV 2.0 送審前的單一 bundle／archive preflight 入口。它只讀取既有產物與 source manifest，不會刪除 DerivedData、修改簽章或連線到 NAS。

```sh
Native/scripts/qualify-app-store.sh
```

`run-fast-gates.sh` 是日常開發與 `main` CI 的快速守門：固定要求 Rust 1.98.1，執行 Rust fmt／Clippy／workspace tests、Swift↔Rust bridge、Swift package tests，再做 macOS 與 iPad Simulator 的 arm64 Debug build。它刻意不做 universal archive、App Store qualification 或 MissionCenter Doctor，避免每次小改都跑完整發行流程：

```sh
Native/scripts/run-fast-gates.sh
```

`run-local-gates.sh` 是發行前完整本機回歸入口，依序驗證 **Rust 1.98.1 toolchain contract**、Rust／Swift 測試、macOS／iPad Simulator Release build、兩端 bundle preflight、canonical archive strict preflight、repository whitespace、MissionCenter sync 與 Doctor：

```sh
Native/scripts/run-local-gates.sh
```

歷史的 V3／N10 SHA-256 artifact snapshot 已搬到 `docs/history/` 保存證據，不再拿固定在 2026-08-29 的 source hash 阻擋今天的正常程式修改。現行 gate 改為驗證版本化工具鏈契約與實際 build／qualification 結果。

預設驗證 `/tmp/CMV-macOS-universal.xcarchive`。Simulator 或未簽章的 generic device bundle 使用 `--app`、`--expected-arches` 與 `--skip-codesign`；正式 archive 不得跳過 codesign。

完整本機 gate 不會自動 commit、push、修改 Apple 簽章、上傳 App Store Connect 或關閉實機／TestFlight 任務；那些仍由 release gate 明確追蹤。

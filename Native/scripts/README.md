# Native scripts

`qualify-app-store.sh` 是 CMV 2.0 送審前的單一 preflight 入口。它只讀取既有
產物與 source manifest，不會刪除 DerivedData、修改簽章或連線到 NAS。

```sh
Native/scripts/qualify-app-store.sh
```

`run-local-gates.sh` 是本機回歸的一鍵入口，依序執行 Rust／Swift 測試、macOS／
iPad Simulator Release build、兩端 bundle preflight、canonical archive strict
preflight、artifact manifest、MissionCenter sync 與 Doctor。它不會自動 commit、
push、修改 Apple 簽章或關閉實機／TestFlight 任務：

```sh
Native/scripts/run-local-gates.sh
```

預設驗證 `/tmp/CMV-macOS-universal.xcarchive`。Simulator 或未簽章的 generic
device bundle 使用 `--app`、`--expected-arches` 與 `--skip-codesign`；正式 archive
不得跳過 codesign。

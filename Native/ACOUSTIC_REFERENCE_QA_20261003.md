# CMV 聲學比較驗證報告（2026-10-03）

這是 4 首本專案原創 WAV 的獨立 comparative QA。結果使用 ±0.1 LU 容差；它不是 EBU/ITU 認證，也不代表完整 programme loudness、其他聲道配置或所有 genres 的矩陣驗證。

## 結果

| WAV | CMV integrated loudness | reference integrated loudness | delta（CMV - reference） | 結果 |
|---|---:|---:|---:|---|
| `01-cobalt-echoes.wav` | -5.420386 LUFS | -5.420146 LUFS | -0.000239 LU | PASS |
| `02-amber-circuit.wav` | -5.337303 LUFS | -5.337146 LUFS | -0.000157 LU | PASS |
| `03-violet-tide.wav` | -5.753596 LUFS | -5.753272 LUFS | -0.000324 LU | PASS |
| `04-silver-orbit.wav` | -5.102069 LUFS | -5.101958 LUFS | -0.000111 LU | PASS |

四筆差異都小於 ±0.1 LU。

## Provenance

- 測試素材是本專案產生的 4 個 stereo、16-bit、44,100 Hz PCM WAV。
- `01-cobalt-echoes.wav` SHA-256：`96da3f07d7f89419a3b78c770863e25c4e262ac1e8bea030a755e353fd8ce0f0`
- `02-amber-circuit.wav` SHA-256：`b43fa0ebbadae98d00dd2af5016ab390f976e75d3481328bebf634ae9a17b7c7`
- `03-violet-tide.wav` SHA-256：`dc4b3b5d1cfa511bd6d30b765bfe341762bf2c4cc83158b7c95231dc0581f001`
- `04-silver-orbit.wav` SHA-256：`825775d8a808510dd0e935d67c9afdd85e43c07cc208f592b858764ffabc9377`
- fixture manifest SHA-256：`4d0b44e8390b8be280c19e06e717b2a87a27b11614155c1df3db3daeba253591`
- CMV Rust 分析來源：`Native/CMVCoreRS/src/analysis.rs`，source commit `2ac1fbf9b30faf4ada7799cf125c058ee90b3430`，檔案 SHA-256 `69997f5ee4dd5fa2e316dc5f483f4380af018eaed475f324eb7622c3a6ba52c8`。

Reference 使用 [ruuda/bs1770](https://github.com/ruuda/bs1770)，pinned `bs1770` 1.0.0 commit `830353a3c1ab6acd1ce2015398ba7969ca71a2ed`，採 Apache-2.0 [license](https://github.com/ruuda/bs1770/blob/830353a3c1ab6acd1ce2015398ba7969ca71a2ed/LICENSE)。WAV 讀取使用 `hound` 3.5.1；Cargo registry checksum 為 `62adaabb884c94955b19907d60019f4e145d091c75345379e70d1ee696f7854f`。

## 流程與重現

Reference 流程依 upstream API 組合每聲道的 `ChannelLoudnessMeter`、100 ms windows、`reduce_stereo` 與 `gated_mean`。CMV 路徑呼叫既有 `cmv_core_rs::analyze_pcm`；兩者都以同一份 16-bit PCM 樣本除以 32768 正規化。沒有重寫另一個 loudness meter，也沒有下載或分發 EBU reference audio。

在具備本地 scratch Cargo project 的環境，可用下列 placeholder 重新執行；`<local-scratch>` 代表未納入 repo 的臨時專案，`<media-fixtures>` 代表本地原創 WAV 目錄：

```sh
CARGO_INCREMENTAL=0 \
CARGO_TARGET_DIR=<local-cargo-target> \
cargo run --locked \
  --manifest-path <local-scratch>/Cargo.toml \
  --release -j 1 -- <media-fixtures>
```

這次驗證只保留比較數據與 provenance；沒有新增 app 依賴、修改 CMV source、修改既有 fixture 或聲稱商業／審核認證。

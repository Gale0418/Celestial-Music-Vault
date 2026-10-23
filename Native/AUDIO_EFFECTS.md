# 音效局部 extension

最新「下一個音色」與暫時原音對照、候選驗證範圍見 [PLAYFUL_LISTENING.md](PLAYFUL_LISTENING.md)。下方既有測試數與交付記錄保留其歷史範圍；後續品質補強見 [SELLABLE_QUALITY.md](SELLABLE_QUALITY.md)。

這是 Celestial Cloud Atlas 的局部 extension，沿用既有主題角色、原生 SwiftUI
控制、系統字體／SF Symbols、material 層次與 44 × 44 pt 操作目標。它只描述音效
功能的入口、狀態與驗收；不新增 design token，也不建立另一套視覺系統。

## 使用入口

- Mac／iPad 寬版播放列的 full layout 與窄寬度切換後的 compact layout 都放置
  `AudioEffectsButton`。
- iPad `MiniPlayerBar` 直接提供同一個按鈕。
- `SettingsView` 的「播放 → 音效」`NavigationLink` 開啟同一個
  `AudioEffectsPanel`。
- 按鈕開啟 `NavigationStack` popover；窄版會採 sheet adaptation。面板維持原生
  `Form`、grouped form、主題 tint 與完成按鈕，不改變播放列或設定頁的資訊架構。

## 面板內容

音效模式分成三組：

- **4 個等化器：** 原音、低音增強、人聲、電子。
- **8 個音場場景：** 土星大氣層、軌道環繞、下水道、深空電台、老卡帶、水下、
  大教堂、浴室演唱會。
- **自訂音效：** 混響、延遲、低音、濾波截止、音場寬度、失真六個參數。

強度是 0–1 的連續值，以百分比呈現；0% 等同原音，原音 preset 會停用強度控制。
自訂參數目前的 bounded ranges 是：混響 0–100%、延遲 0–500 ms、低音 −12–+12
dB、濾波截止 150–20,000 Hz（對數 slider）、音場寬度 0–2×、失真 0–100%。

「恢復原音」寫入新的 `AudioEffectsSettings()`，回到原音模式、預設 30% 強度與中性自訂參數。
設定使用 `CMV.audioEffects.v1` 存於 `UserDefaults`；載入與儲存都先做 finite／range
驗證，損壞資料回到原音。AppModel 啟動時載入，更新時同步播放 engine 並保存，因此
重啟會保留設定而不觸碰 queue 或播放狀態。

## 播放與即時 graph

2026-10-05 續作已將影片音效接到既有 `AVPlayerItem` 的單一 audio tap，音樂與影片
共用已保存的 preset／強度／自訂參數與暫時原音比較。影片的實際 PCM 交給獨立
realtime manual-rendering graph 同步處理，再回到同一條 AVPlayer 時間軸；不另開
一個音訊播放器。

目前支援本機檔案、單一音軌、44.1／48 kHz、Float32、mono／stereo 的標準 packed
PCM。無音軌、串流、多音軌、未支援格式或處理失敗時保留原音，面板顯示原因；準備
狀態與實際可用狀態分開。非中性音效要有真正成功的 wet render 才宣告可用，原音、
零強度與中性自訂設定保留 dry PCM。Core 的 13 項焦點測試已通過；App 與實機
影音同步／seek／PiP 的最終驗收尚在執行，詳見 [剩餘驗收報告](REMAINING_VALIDATION_REPORT.md)。

Native playback graph 是既有時間軸上的：transition mixer → live effects AU →
reverb → delay → distortion → 4-band effect EQ → 10-band EQ → limiter → main
mixer。預設切換與自訂更新只改已連線 Audio Unit 參數，不重排 player node、不改變
sample rate，也不重排 gapless 時間軸。

live AU 的音樂路徑維持既有雙聲道格式；影片 graph 依實際取樣率建立內部雙聲道
處理，再寫回原始 mono／stereo buffer。`Orbit` 是左右聲道之間的慢速 sweep／balance，刻意是
stereo effect，不宣稱 3D 或 spatial positioning。delay ring 在 render resource
配置時預先配置；控制值以 atomic 傳遞，render thread 不配置記憶體、不上鎖、不跳
actor，並以約 25 ms slew 平滑參數變更，避免 click。

音效測試使用同一個 `NativePlaybackEngine` 的 DEBUG manual-render graph（含 live
AU 與 limiter）；它不是獨立的仿真 DSP。這個入口只供測試，不是產品播放模式。

## 驗收摘要（2026-10-04）

- Rust：33 項／0 失敗；Swift 完整套件：92 項／0 失敗；hosted preferences：2
  項／0 失敗。
- CodeRabbit：UI 7 files 與 Core 4 files 均 0 issues。
- Mac、Simulator、實機 iPad 的 Release build 成功；Desktop 同路徑覆蓋
  strict-sign 檢查 PASS。
- CUA mode 13、重啟後 31% persistence、6 個 custom controls 的 AXIncrement 真
  binding 與 Reset 通過（Mac 限定）。Simulator 直式／橫式 popover，以及全部 menu／Settings
  入口可見；橫向以原生 Scroll Down 實際捲到下半部並點 Reset 回原音。
- 實體 iPad 使用 `com.windsheep.cmv` 安裝成功；最後啟動停在 Locked、需要解鎖，
  因此不能標記為 launch PASS。

以下項目仍不能算通過：實體聽感、AirPlay、完整 VoiceOver／Dynamic Type、低延遲
profile、影片 actual route。物理 drag 工具本輪未觸發；原生 AX 捲動可達性已確認。AXsetValue 只改變
widget 而 label 沒有同步更新，故不列為通過。

獨立 Impeccable finish review 最後 disposition 為 `fix`：原生 AX 可達性已有證據，
實體 iPad touch scroll／Reset 尚待解鎖後補驗；FX36 保留 Review。

Release gates 仍未完成。舊 Electron 40 tracked files 與約 361 MB ignored build
cache 已移除；復原基準是 `7e033ae3b776f116695b3f2df0f0293bd76322f9`，既有曲庫
音樂憑證保留。文件不記錄裝置 ID、曲庫歌名或私密 profile。

## 後續限定 QA

只補尚未驗證的 boundary：解鎖後實體 iPad 再啟動並操作一次、實機聽感與影片
actual route、完整 VoiceOver／Dynamic Type、低延遲 profile，以及可觸發的
實機 touch gesture。AXsetValue widget 值不能當作產品 binding 驗證。這些完成前，維持目前的 release gate 未完成
狀態。AirPlay／Bluetooth 與完全斷網依本輪使用者指示排除，不再列為本輪待驗。

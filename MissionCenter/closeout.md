# 收尾

- 摘要: AeroMusic 1.0.0 已完成可靠性、安全、效能、離線體驗與 macOS 發行強化並交付桌面。
- 已完成: 原子存檔與備份復原；NAS 離線保護；Electron/IPC/導航 hardening；20,000 首排序；離線資源；Chrome 與封裝 App 回歸；Apple Development 本機簽章；DMG 交付
- 未完成: 正式對外公證需另備 Developer ID Application 憑證與 notarytool profile；非本次本機交付阻擋
- 風險: 預設示範串流仍需 SoundHelix 網路；Apple Development 簽章不等於 Developer ID 公證
- 冒煙測試: npm test；零警告 lint；Vite 8 build；audit 0；Chrome UI；Electron 單例；codesign strict；hdiutil verify；桌面啟動
- 回顧: NAS 專案應固定在 /tmp 乾淨建置；成品 plist 必須在簽章前 fail-closed 驗證；UI 與成品實測能抓到單元測試外問題

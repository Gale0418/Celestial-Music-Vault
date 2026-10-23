# CMV 2.0（1）Distribution 成品檢查點

## 現行候選（2026-10-09，固定土星構圖與左右入口版）

現行候選為 `latest-release-prepared-01`，95 份 production source 在 ordinary Mac／Distribution 建置前後及現行工作樹全部一致。主代理重新檢查 iPad／Mac 的 archive 與 export App，四項 `qualify-app-store.sh --distribution` 均實際 exit 0；archive／export／dSYM UUID 各平台一致。以下 SHA 為封存成品實際讀回值，沒有上傳、提交或發布。

| 現行成品 | 架構 | bytes | SHA-256 |
|---|---|---:|---|
| Mac `CMV.pkg` | arm64、x86_64 | 18,288,374 | `9b8a327994de83f4e053bf9e6d119f45c88384ccce4b32d3173cc15d2883fd21` |
| iPad `CMV-iPad-arm64-latest.ipa` | arm64 | 14,804,404 | `2f362464b41929b844c0e2af2196159491eb4fdf979419b7bccdd620e3525bc9` |

[成品封存](../.cmv-local-evidence/2026-10-09-task-zero/latest-release-prepared-01/reports/report.json)；[主代理 qualification 與 UUID 證據快照](../output/mission-center-critique/AERO-RC4-20261009-final-S01/snapshot.json)。iPad arm64 UUID `153DBEB4-6B43-341F-A2FE-DC28385F8F16`；Mac arm64 `8CCEA7FB-F3FF-3488-BDC9-8949DFD260DE`、x86_64 `5901211B-393D-39E1-8BF7-D707D8FFB4CD`。

Resource-input verifier 原將 Mac 專用權限套用 iOS，並把 Apple 自動加入的 identity 欄位視為 source drift；已修正 SDK scope，獨立驗證 Info／profile／Team／App ID。未知 SDK selector、額外／缺少能力與錯誤外部 SHA 均拒絕；缺 profile 明記身份未驗，不宣稱完整通過。主代理重跑 8 項測試 exit 0，含兩平台現行出口；只修檢查工具，沒有修改 production source 或重建成品。原失敗紀錄保留。

Mac 普通 Release 已原路徑覆蓋並正常啟動，iPad UI 候選的固定土星／左右按鈕與混合 queue 實測分別封存。歷史 runtime PASS 依 source lineage 保留，不能把 Distribution 包裝驗證冒稱正式出口已完成全部 GUI 旅程。實體 iPad 最新 Wi-Fi tunnel disconnected；商店 native captures／影片、剩餘矩陣與四席正式收尾尚未完成。

## 歷史候選：sidebar-count-fixed（2026-10-08 晚間，已取代）

最新本機候選是 `sidebar-count-fixed-artifacts-01`，兩平台皆為 2.0（1）。本輪重新讀回 IPA／PKG，大小與 SHA 全部符合封存 manifest；archive 版本／build 亦一致。四份 archive、95 項來源、binary／dSYM UUID 與六項 qualification 的綁定見該封存 `primary-artifact-binding.json`。這些證據不代替 Distribution 出口實機驗收或 Apple 審核。

| 最新成品 | 架構 | bytes | SHA-256 |
|---|---|---:|---|
| Mac `CMV.pkg` | arm64、x86_64 | 18,273,769 | `fa70a91f87e5d6f87f5ec559892886a5f80c4feab1f9f7ecdd54722d097a200b` |
| iPad `CMV.ipa` | arm64 | 14,796,596 | `ce5aa51047ecac400beaa3a95ebec21ee84b36f31c6b9ce5f5e9530848dbd169` |

[最新封存入口](../.cmv-local-evidence/2026-10-08-task-zero/sidebar-count-fixed-artifacts-01/manifest.json)：243 payload，manifest SHA `964573001287e44c6ffb6298f095764698fe17124dc3f34276487cea8c6aceca`。晚間 iPad 已補歌單／Smart DJ／播放中佇列與冷啟動、分析／移出計數；各切片與還原限制見[測試總帳](../MissionCenter/tested-coverage-ledger-20261008.md)。自訂七值冷啟動及對照通過；主人重開後的偏好還原已核實，另完成四EQ冷啟動保存。四EQ測後effects解析值exact，但encoded JSON key order不同，詳總帳；歌曲維持暫停。

同 RC 商店截圖／影片、剩餘矩陣與正式四席評論未完成，未上傳／送審。原評論預算 hard stop 已由主人撤除；下方時間紀錄中的預算中止只描述當時狀態。

## 歷史候選：metadata-fixed（已由上述候選取代）

2026-10-08：標準 m4a 曲／碟序匯入修復後，Mac universal 與 iPad arm64 已重新 archive／export。主代理親核四份 archive／出口 App 的 Distribution qualification、strict codesign、profiles、binary／dSYM UUID，以及 Mac PKG 簽章，均 exit 0。95 檔 production source 的 build 前／後／現行 SHA 全同。這是該階段的本機發行候選；整體 RC、TestFlight、上傳與送審尚未完成。

| 該歷史候選成品 | 架構 | bytes | SHA-256 |
|---|---|---:|---|
| Mac `CMV.pkg` | arm64、x86_64 | 18,257,143 | `dd8e48f832d5fff33c12828b765004e60a7cb61ed701459d5078c677fc1b29a5` |
| iPad `CMV.ipa` | arm64 | 14,790,512 | `19cedc64f1b6067fae6b940f1543c470ab2ec55df592fca1456e8aa622345ffb` |

## 主代理親核與證據

Ignored `.cmv-local-evidence/2026-10-08-task-zero/metadata-fixed-primary/`：140 payload manifest SHA `14a151a979b677a4dba684ffa0d47e6c93b791c7ab8530f1aee2cb84989020f2`，含四份 qualification／codesign／profile 讀回與實際 package SHA。所有 bundle 均為 `com.windsheep.cmv`、`2.0 (1)`、Pro ID `com.windsheep.cmv.pro.v1`，Privacy Manifest 與 source 相同。

- Profiles：`get-task-allow` 為 false 或不存在；`ProvisionedDevices` 不存在、`ProvisionsAllDevices` 非 true；signed 與 profile application identifier 完全一致。
- Mac binary／dSYM UUID：x86_64 `D031F56B-286A-366C-A402-79D2C1D0467E`、arm64 `2E6004C9-8409-36D4-B52C-53D0B8194DAC`。
- iPad arm64 binary／dSYM UUID：`C51FB3A5-474B-3319-970B-5775B3434B50`。
- Archive 與出口重新簽署後的 executable SHA 各自綁定實際成品，不要求不同簽署階段的整個 binary SHA 相同；目錄使用逐檔 manifest。

原始 stage：`/tmp/cmv-task-zero-20261008/metadata-fixed-artifacts/`。Development 另列於 `receipts/development-manifest.json`；正式成品列於 `receipts/artifact-manifest.json`。完整成品封存已完成，入口為 ignored `.cmv-local-evidence/2026-10-08-task-zero/metadata-fixed-artifacts/`。`sealed-payload-manifest.json` 綁定 388 檔、359,983,193 bytes，manifest SHA `5ceb3bd2cc6b2e18e6ade66654b53c3b239c514cd0f836b05b9f85f80f98710a`；包含 95 production source、Development／Distribution archives、PKG／IPA、解包 App、raw logs 與收據，排除 DerivedData 與私人資料庫。

## 曲／碟序修復與 App 回歸

205 份合法小型 m4a 的真實匯入重現 `itsk/trkn`／`itsk/disk` 被 scanner 過濾、曲／碟序全 nil。Parser／Scanner 已共用 exact classifier，拒絕不相干 tag。修正前 parser／scanner exit 1，修正後 parser／205 檔 scanner／既有 parser focus exit 0；fixture test 缺少 `CMV_SORT_FIXTURE_ROOT` 時會 XCTSkip，不能宣稱一般 CI 自動覆蓋。

Mac 已同位置覆蓋新 Development App，executable SHA `a41fbc5e5938dd15aa9fb7b29082033fc5336d8b56402847de490e8385c867c0`。GUI 重新匯入後，九項 metadata 各 205 筆完全一致；歌曲資訊 T200 實際顯示曲序 200／碟序 3。測後六檔停機還原 byte exact，重啟後九表全 schema／欄位一致、queue 非 revision 一致（301→304）、App-owned preferences 一致。iPad 修正版 runtime 由獨占操作 worker 續驗，未借用 Mac 結果。

修復封存 `metadata-track-disc-fix/`：27 payload manifest SHA `407354111b7ca2a13799d91b4a6f41c42fff4807f4b0e280b82271439f2adf1f`。Mac 回歸 `mac-metadata-fixed-runtime/`：13 payload manifest SHA `55d5720af444cf564557df9d8badf9f9691d77f94d5ea665bbbdab327dd4c130`。

## 限制

三次 Development recipe 失敗分別為 Xcode-managed profile 與 Manual 衝突、cwd、identity 衝突；原始 exit／log 與成功收據保留，未建立或撤銷簽章資產。修復前 `distribution-current/` 的 251 payload／manifest SHA `75ed75bda8dfd10df9f8d9f6aeff28c5acd4caea0c39b90e2d9a63111648f270` 保留為歷史候選。

尚未安裝 Distribution 出口、上傳、提交或發布。Development GUI 與正式出口資格各有明確 scope；功能矩陣、同 RC 商店素材與正式結案評論仍待完成。

## 2026-10-08T11:00:56.321093+08:00 本次實測完成／正式評論凍結

Mac與iPad最新Development真匯入205，九metadata欄位各205 exact；iPad正常iCloud立即下載後成功，latest source掃描時間非null，完整9表／queue／prefs父代理親核已還原。其他進階欄位／批次矩陣仍待驗。 Mac排序四欄八方向可見頭尾／200-201 PASS_SCOPED；iPad最新真2selected後指標點播放所選→僅owned T001/T002 queue、T001播放、raw index1；資料完整還原。完整歌單／移出等矩陣仍待驗，第二首獨立播放frame UNKNOWN。 Mac最新exact3-owned隔離queue起index0後index2/history3、Cobalt最後EOF paused，支持scoped traversal；未捕捉Amber/MOV獨立EOF或gapless音訊，不假完整12sec影片PASS。9表／queue／prefs還原已親核；iPad完整queue矩陣待驗。 正式評論已獲30k/7500tokens、32/8tools、45min含delta上限；實測已收束，資料已還原，未轉Done／未上傳或送審。
 Latest Development runtime evidence不等於Distribution runtime；最新exports／資格未改。

## 2026-10-08T11:37:40.309381+08:00 末項影片修復後候選失效範圍

AppModel.swift及VideoExperienceView.swift兩production inputs已變。以上metadata-fixed成品與簽章資格保留為歷史候選，不代表包含末項EOF佇列保留／重播修復。3焦點host測試PASS，實機重播及新雙平台Development／Distribution尚待；新iPad archive正在建置。未上傳或送審。證據terminal-video-queue-fix-01／27payload manifest ba48fb57b9203b1fee282159a0c9dce9aef9a99140b42c3cc8ade75983e0a818。

## 2026-10-08T11:44:37.082261+08:00 修復版iPad EOF／重播實機完成

asc xcode archive actual0，2.0(1)同bundle com.windsheep.cmv覆蓋安裝／launch success，staged strict codesign0。95production來源在建置中取樣及完成後exact；不是起跑前取樣，前述口頭「前後」應以此精確收據scope解讀。staged binary SHA見build-binding，不冒device直接hash。正常provider匯入6首自有來源available；只選owned12secMOV播放，GUI naturalEOF paused0:12/0:12且queue1保留。按play回0:00再前進0:07，snapshot start／EOF／replay同occurrence及index0 exact。單一影片PASS_SCOPED，不代替新版混合route／播放中mutation／gapless。

測後原9tables schema／全cols rows exact、integrity ok、queue非revision238→241 exact、prefs全keys exact，GUI回19首原曲paused0:00/5:50。封存terminal-video-ipad-runtime-01，34payload／manifest SHA1d1a4e4a96b5f165565af8c3fbe643fe555e09942f7c0230182e1493aeb9f377，親核SHA/bytes0mismatch；包含新iPad Development archive、sanitized觀測與還原收據，不含私人DB／prefs。Mac Development與雙平台Distribution正在另建；舊成品留歷史，未upload／submit／critic續派或Done。

## 2026-10-08T12:32:27.876312+08:00 播放中mutation停滯／Core修復及新候選

iPad正常provider匯入6首owned素材，播放中重排Silver、移除future Violet、追加Cobalt及精確移除新duplicate有GUI與queue讀回。期間一次人工Previous把長音訊回0，不稱全程無seek；移除後raw較晚已自然advance index1。Silver0:06在fresh screenshot／source仍停，確認真管線停滯，完整traversal FAIL。9表schema／全部cols rows exact、integrity ok、queue非revision241→244 exact、prefs全keys exact、GUI原19首paused已還原；未播放私人曲目。22payload封存ipad-playing-queue-runtime-01，manifest4077ee35a99a28d7ceeeefe6bf677410bc2e12900ecce809006dfc21d34646ed，SHA/bytes親核0mismatch。

NativePlaybackEngine standby stop後未restart且node sample clock reset；修復專用schedule世代、node timeline origin與共同host time啟動，保留active播放。async next-file open以token識別ownership；開檔中曲目ID修復時先釋放owned旗標再排latest route。原route1test／3assertfail；第一修復後ID修復邊界另1test／3assertfail，raw保留，不混稱同一舊來源。最終45受影響XCTest PASS、0fail／0skip，含paused mutation／seek後實際render deadline／ID修復延遲開檔；git diff check0。修復14payload manifest8f869b5511228e1b1ccb7cedca2f3caf43680bf1753f2f3695104c380769deb1，親核0mismatch。最新Core雙端實機待，不代替完整gapless音訊量測。

前terminal-video四archive／二出口／六qualification全0，95source及四組dSYM/binary UUID親核；281payload manifest fdb19fa919f53ef56b87526d40b5901306985a29377ac364a505143a5c4f7209，SHA/bytes0mismatch。未含最新Core修復、留歷史，Mac未覆蓋此候選。standby候選01 iPadDev0/sourceExact true、MacDev0/sourceExact false，guard拒絕並exit1；兩Distribution未執行，無export／qualification／install。最終來源另凍結95inputs候選02重建，復用四cache、jobs2，不清activecache、不重置正式評論預算。fresh Available12,437,388KiB約12.7GB，非原30GB。未轉Done／upload／submit。

## 2026-10-08T12:41:53.929742+08:00 最終standby修復成品封存親核

standby-fixed-artifacts-02四archive actual0／各95sourceExactAfter true；iPadIPA及MacPKG exports0，兩Development與四Distribution archive/export六qualification全0。四組binary/dSYM UUID exact（iPad各1架構、Mac各2）；95source唯一delta為NativePlaybackEngine.swift，包含terminal-video修復及最終standby／ID修復ownership修正。251payload／276,527,640bytes，manifest9e24ee172f0c13fd6800c51049eaf4c132700acfab0c672f6c71971855f20f59；root逐檔SHA/bytes0mismatch。出口SHA及大小見封存primary-artifact-binding.json。

iPad同IDinstall success、staged strict codesign0，但launch Locked拒絕，待主人手動解鎖才能進最新Core真實播放矩陣；Mac新版未覆蓋／GUI實測。host45tests不是整體gapless實機量測。正式council仍預算中止，不續派／重置；未轉Done、未upload／submit／publish。已完成且本次owned舊測試cache兩目錄回收728,324KiB（約746MB），兄弟logs／三xcresults／封存／private baseline／WDA及relay保留。清後Available12,632,756KiB約12.9GB，不稱恢復30GB。

## 2026-10-08T12:51:37.760787+08:00 最新Core Mac覆蓋／播放中mutation及自然混合路徑

原Desktop/CMV.app正常退出，保存最新六檔baseline，使用最新Development原路徑覆蓋；strict sign0、exe7de24e43…cc477c87及95source exact、實際PID路徑綁定。正常picker加入同owned6首、PlaySelected。Long0:40播放中Silver移到最前、0:52移除Violet、1:31追加Cobalt不同occurrence、1:57精確移除尾項duplicate；原Cobalt保留。沒有manual seek／Previous／Next。最後duplicate raw較晚採樣已自然advanceSilver index1，GUI與raw時點分開。Silver0:07/0:18→Cobalt0:04/0:20→Amber0:14/0:19→MOV0:01→0:10/0:12均直接CUA觀察；naturalEOF paused12/12，queue5/index4/原occurrence保留。按play0.500→11.750s，支持末項replay實際前進。不是聲學gapless量測、不是iPad新版證據。

測後六檔停止態byteExact，重啟9tables schema／全cols rows exact、integrity ok、queue非revision313→316 exact、AppOwned preference keys exact；NSWindow Frame generated key／SKTransactionUpdatesLastChecked系統keys變動、externalprefs全keys exact，不冒完整prefs全keys一致。GUI原1971paused0:00/6:25，未播放私人曲目。封存mac-standby-fixed-runtime-01，直接CUA觀測／自有queue與sanitized restore、無privateDB/prefs。正式評論budget仍中止、iPad待解鎖；下一補批次／歌單矩陣，未轉Done／upload。

## 2026-10-08T13:11:11.835837+08:00 Mac歌單批次封存／側欄count P2修復重驗

Mac批次/歌單18payload manifest83c90d31b92377f4bf7b8eedc6b377c3323c4d076db970de922283dde0362b28，root SHA/bytes0mismatch；六首加入、順序上下移、單首移出、批次取消與五首移出、empty QA歌單清理、取消選取及logical exclude兩首均實測。原7檔SHA/bytes未變，9表及queue非revision316→319、AppOwned prefs完整還原；系統NS/SK keys差別保留。sidebar仍1977而expected1975已確認P2。AppModel exclude後increment libraryRevision，Sidebar task ID加入revision並沿用取消guard；僅兩檔delta，diff check0。新95來源凍結，MacDev archive actual0/exact true，已同Desktop路徑覆蓋，受影響GUI重驗中；另三archive背景續建。未稱新iPad安裝或PASS。

Mac Core queue26payload manifest6755c69b69c5679a9d56a0dc3afd28554db083dd947bd14a4188653cdc12e9e4親核0mismatch。iPad仍需手動解鎖；正式council原budget超限中止，不重置/續派；未Done/upload/submit。

## 2026-10-08T13:28:33.543039+08:00 count修復實機PASS／最新iPad阻擋解除

主人手動以正常picker加入本機exact7檔副本，six playable indexed/source available。工具前述Open disabled與coordinate noWindowsAvailable保留為操作限制；實際人工成功，不判confirmed產品importer缺陷。Mac新版同Desktop binary d616a35e…245fd，Long單曲menu移出後1977→1976/filtered6→5；Cobalt批次單選入口移出後1976→1975/filtered5→4，raw僅兩owned excluded，原/cloud及本機7×2檔SHA/bytes exact。未重跑latest一次batch2；舊candidate batch2logical PASS/count stale FAIL證據留存。停止六檔byteExact，重啟9表全欄schema/rows exact、integrity ok、queue非revision319→322 exact、AppOwned prefs exact，systemNS/SK變動、external全keys exact。GUI原1971paused0:00/6:25。13payload封存mac-sidebar-count-runtime-01 manifest99e7f5b3063363f274a07c50b34f3e5eb873f62f4c295b75befe928e1335b7eb，SHA/bytes親核0mismatch；完整baseline/private snapshots保留tmp，已回收owned本機36MBfixture及上版App scratch。

latest四archive0/95sourceExactAfter true、兩exports0、六qualification0、四UUIDbinary/dSYM exact。IPA14,796,596bytes ce5aa51047ecac400beaa3a95ebec21ee84b36f31c6b9ce5f5e9530848dbd169；PKG18,273,769bytes fa70a91f87e5d6f87f5ec559892886a5f80c4feab1f9f7ecdd54722d097a200b；完整成品封存寫入中，不冒manifest已完成。主人解鎖iPad後新countfix same-IDinstall/launch success，staged binary064c53fb…17a39，未device directhash；fresh five-file baseline保存，GUI owned矩陣續驗。未Done/評論續派/upload/submit。

### 2026-10-08T23:30:12.622956+08:00 iPad metadata/sort delta

2026-10-08 iPad 八欄 metadata 與六欄十二方向首頁切片完成，11 payload manifest 20d70670aaad6cf4ae83f0bd5500c41dc3c3231dce8baebf796528810ce7decb。preview未寫入/only2八欄/其餘618不變/undo620八欄 exact；Song Info 八欄及時長/加入日期直接可見，當日default日期不冒日曆編輯。sort每組前12對205真實資料 strict exact，末頁/跨分頁/時長評分distinct仍待。測後9表全欄列/queue268→271非revision/effects encoded/全部prefs exact，GUI原19首0:00paused。誤點兩首owned離線釘選新增2失敗0，cache不冒還原。WDA host04意外exit65，host05 existing product/test timeout NO與relay06恢复，未重build或重裝CMV。Mac當次剩8,245,516KiB，不冒30GB目前空間。任務原狀態保留，未上傳/送審。

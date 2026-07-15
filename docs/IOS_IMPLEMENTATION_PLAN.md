# 留痕 Trace：iOS 實作執行計畫

> 文件版本：1.0
>
> 文件日期：2026-07-15
>
> 規格基準：[IOS_ENGINEERING_SPEC.md](./IOS_ENGINEERING_SPEC.md) v1.1
>
> 程式基準：Git commit 01b20de
>
> 目標版本：External Beta Candidate

## 1. 執行結論

目前 Repo 是可編譯的產品原型，已有事件、附件、OCR、Share Extension、Face ID、備份及單事件 PDF。下一階段不能直接從 Apple Intelligence 畫面開始，因為語音、OCR 與 AI 產生的內容都必須建立在「原始資料不可覆寫、修訂可追溯、刪除完整」的資料底座上。

實作採以下順序：

1. 建置與測試底座。
2. SwiftData Schema v2 與資料遷移。
3. 原始附件儲存、完整性與完整刪除。
4. Share Extension v2 與聊天截圖整理。
5. 可見式錄音與音檔保存。
6. SpeechAnalyzer／SpeechTranscriber。
7. Apple Intelligence 結構化草稿。
8. 多事件 PDF／ZIP 案件包。
9. 備份、隱私、安全與 TestFlight。

App deployment target 維持 iOS 17；Speech 與 Foundation Models 以 iOS 26 availability 隔離。External Beta 必須完成新功能，但模型不可用時仍能以固定問答完成事件。

## 2. 現況與主要差距

| 領域 | 現況 | 必須完成 |
|---|---|---|
| 建置 | XcodeGen、單一 simulator build | Xcode 26、Unit/UI test targets、fixture、CI tests |
| SwiftData | TraceEvent、EvidenceAttachment 兩個可變模型 | VersionedSchema、migration、revision 與衍生資料模型 |
| 原始資料 | narrative、rawOCRText 可直接修改 | 原始版本唯讀，所有修正另存 revision |
| 檔案 | 單層 Evidence 目錄 | staging、原子寫入、衍生檔、operation journal、完整刪除 |
| Share Extension | 可接收多圖 | 固定 orderIndex、SHA-256、idempotent batch、錯誤復原 |
| 聊天整理 | 單張 OCR 文字欄位 | ConversationGroup、人物、訊息分段、跨圖排序與確認 |
| 語音 | 可從 Files 匯入音檔 | App 內錄音、狀態、中斷、原始音檔與雜湊 |
| Speech | 尚未實作 | iOS 26 SpeechAnalyzer、資產狀態、分段、確認與降級 |
| Apple Intelligence | 尚未實作 | availability、guided generation、來源追溯與審閱 |
| 輸出 | 單事件摘要 PDF | 多事件 PDF、原始附件 ZIP、manifest 與逐檔雜湊 |
| 安全 | 畫面解鎖、備份 v1 | App Switcher 遮罩、完整刪除、備份 v2 與往返驗證 |
| 發布 | 未簽署 simulator build | Developer Team、App Group、真機、TestFlight 文件 |

## 3. 依賴關係

~~~mermaid
flowchart TD
    W0["W0 建置與測試底座"] --> W1["W1 Schema v2 與遷移"]
    W1 --> W2["W2 檔案完整性與刪除"]
    W2 --> W3["W3 Share Import v2"]
    W2 --> W5["W5 可見式錄音"]
    W3 --> W4["W4 聊天截圖整理"]
    W5 --> W6["W6 Speech 逐字稿"]
    W4 --> W7["W7 Apple Intelligence"]
    W6 --> W7
    W4 --> W8["W8 案件包"]
    W6 --> W8
    W7 --> W8
    W8 --> W9["W9 隱私、備份與安全"]
    W9 --> W10["W10 TestFlight"]
~~~

不可跨越的 Gate：

- W1 未完成前，不新增正式語音或 AI 資料。
- W2 未完成前，不讓測試者保存重要原始證據。
- W6 未有確認逐字稿前，AI 不讀取語音結果。
- W7 的 AI 草稿未經使用者確認，不得進入正式事件 revision。
- W8 未能重新驗證所有附件 SHA-256，不得產生「完整案件包」。

## 4. 工程結構調整

建議逐步整理為以下目錄；XcodeGen 會自動包含 Trace 下的新 Swift 檔：

~~~text
Trace/
├── App/
│   ├── TraceApp.swift
│   └── AppEnvironment.swift
├── Models/
│   ├── Schema/
│   │   ├── TraceSchemaV1.swift
│   │   ├── TraceSchemaV2.swift
│   │   └── TraceMigrationPlan.swift
│   ├── EventModels.swift
│   ├── EvidenceModels.swift
│   ├── ConversationModels.swift
│   ├── SpeechModels.swift
│   └── IntelligenceModels.swift
├── Services/
│   ├── Storage/
│   ├── Import/
│   ├── OCR/
│   ├── Audio/
│   ├── Speech/
│   ├── Intelligence/
│   ├── Export/
│   ├── Backup/
│   └── Security/
├── Features/
│   ├── Events/
│   ├── Conversation/
│   ├── Recording/
│   ├── Transcription/
│   ├── Intelligence/
│   ├── Export/
│   └── Privacy/
└── Resources/

TraceTests/
├── Models/
├── Storage/
├── Import/
├── Speech/
├── Intelligence/
├── Export/
└── Fixtures/

TraceUITests/
└── Flows/
~~~

不要求一次搬完現有檔案。每個工作包只移動正在修改的功能，避免大型無功能重構。

## 5. 工作包

### W0：建置與測試底座

目標：讓每個後續資料變更都有自動驗證，並讓 iOS 26 API 能在 CI 編譯。

修改：

- project.yml
- .github/workflows/ios-build.yml
- README.md

新增：

- TraceTests/
- TraceUITests/
- TraceTests/Fixtures/

工作：

- 在 project.yml 增加 TraceTests 與 TraceUITests targets。
- 建立 in-memory SwiftData 測試容器 helper。
- 建立臨時 Application Support 目錄，測試不得寫入正式 App 路徑。
- CI 固定使用具備 iOS 26 SDK 的 Xcode 26。
- CI 執行 XcodeGen、build、unit tests；UI tests 可先以獨立 job 啟用。
- 建立不含真實個資的圖片、PDF、音檔與對話 fixture。
- 更新 README：語音與 Apple Intelligence 已是 External Beta 必做範圍。

驗收：

- simulator Debug build 成功。
- 空的 Unit/UI test targets 能執行。
- fixture 不包含真實姓名、公司、聊天或聲音。
- CI 失敗時能區分 build、unit test 與 UI test。

建議 commit：Add iOS test targets and Xcode 26 CI baseline

### W1：SwiftData Schema v2 與資料遷移

目標：建立不可變原始資料、修訂版本、聊天、語音與 AI 的正式資料模型。

修改：

- Trace/TraceApp.swift
- Trace/Models/TraceEvent.swift
- Trace/Models/EvidenceAttachment.swift

新增：

- Trace/Models/Schema/TraceSchemaV1.swift
- Trace/Models/Schema/TraceSchemaV2.swift
- Trace/Models/Schema/TraceMigrationPlan.swift
- Trace/Models/EventRevision.swift
- Trace/Models/OCRResult.swift
- Trace/Models/ConfirmedTranscript.swift
- Trace/Models/ConversationGroup.swift
- Trace/Models/ConversationParticipant.swift
- Trace/Models/MessageSegment.swift
- Trace/Models/AudioRecordingSession.swift
- Trace/Models/SpeechTranscript.swift
- Trace/Models/SpeechSegment.swift
- Trace/Models/IntelligenceDraft.swift

工作：

- 將現有模型封裝為 TraceSchemaV1，保持欄位名稱可讀取。
- 建立 TraceSchemaV2 與 TraceMigrationPlan。
- 將既有 narrative 建立為 EventRevision version 1。
- 將既有 rawOCRText 建立為 OCRResult；confirmedText 建立為 ConfirmedTranscript。
- TraceEvent 只保存目前 revision 指向與事件 metadata。
- EvidenceAttachment 增加 byteCount、UTI、完整性狀態、檔案建立時間與 orderIndex。
- 所有 enum 以穩定 raw value 儲存，不以中文 UI 文案作資料值。
- 關聯 delete rule 經測試，不依賴 cascade 刪除實體檔。

驗收：

- 新資料庫能建立所有 V2 model。
- V1 fixture 可遷移到 V2，事件、附件、OCR 與時間不遺失。
- 原始 EventRevision、OCRResult 建立後沒有 UI 修改路徑。
- 新 revision versionNumber 單調遞增且可追溯來源。
- migration 重複啟動不建立重複 revision。

建議 commits：

- Add versioned SwiftData schemas
- Migrate original event and OCR content to revisions
- Add conversation speech and intelligence models

### W2：檔案完整性、操作日誌與完整刪除

目標：原始檔不可覆寫，所有跨檔案與資料庫操作可復原或明確標示待清理。

修改：

- Trace/Services/EvidenceStore.swift
- Trace/Views/EventDetailView.swift
- Trace/Views/AttachmentDetailView.swift

新增：

- Trace/Services/Storage/TraceFileLayout.swift
- Trace/Services/Storage/FileIntegrityService.swift
- Trace/Services/Storage/FileOperationJournal.swift
- Trace/Services/Storage/EvidenceDeletionService.swift
- Trace/Services/Storage/OrphanCleanupService.swift

工作：

- 建立 Evidence、Derived、Exports、Staging 與 Operations 目錄。
- 匯入採 staging → close → SHA-256 → atomic move → SwiftData insert。
- 實體檔名只使用 attachment UUID；原檔名只存 metadata。
- 每次檢視或匯出前可重新驗證 SHA-256。
- 刪除附件先建立 operation journal，處理原始檔、縮圖、OCR、逐字稿與快取。
- 刪除事件列出全部關聯，完成檔案刪除後才回報成功。
- 啟動時掃描未完成 operation 與 orphan staging。
- UI 移除直接 FileManager.removeItem 與 try? 吞錯行為。

驗收：

- 寫入中斷不產生指向不存在檔案的 attachment。
- 修改測試檔後 integrityStatus 變為 mismatch。
- 刪除附件後資料庫、原始檔與衍生檔皆不存在。
- 刪除事件後重啟 App 不會重新出現。
- 刪除失敗會顯示剩餘項目，不顯示假成功。

建議 commits：

- Add atomic evidence file storage
- Add integrity verification and operation journal
- Implement complete attachment and event deletion

### W3：Share Extension v2

目標：多張截圖以使用者選取順序、安全且可重試地進入主 App。

修改：

- Shared/SharedImport.swift
- TraceShare/ShareViewController.swift
- Trace/Services/SharedImportIngestor.swift

工作：

- PendingImportItem 增加 orderIndex、UTI、byteCount、SHA-256。
- provider 建立 task 前固定 orderIndex，完成時依 index 排序。
- 保留原始圖片格式，不將所有檔案命名為 jpg。
- batch 完成後才原子寫入 manifest。
- 主 App 驗證每個檔案大小與 SHA-256。
- 以 batchID 做 idempotency；重試不重複建立附件。
- 主 App 成功建立資料後才刪除 App Group batch。
- 無 manifest 的中斷資料提供清理及診斷。

驗收：

- 20 張不同大小圖片非同步完成後順序仍一致。
- 相同 batch ingest 兩次只建立一組 attachment。
- 損壞、缺檔、錯雜湊不建立半套事件。
- Extension 時間不足中斷後，主 App 可清理或重試。

建議 commit：Make shared image import ordered and idempotent

### W4：聊天截圖整理

目標：從原始截圖形成使用者確認過的人物、訊息、日期與事件關聯。

修改：

- Trace/Services/OCRService.swift
- Trace/Views/AttachmentDetailView.swift
- Trace/Views/EventDetailView.swift

新增：

- Trace/Services/OCR/OCRObservation.swift
- Trace/Services/OCR/OCRResultBuilder.swift
- Trace/Services/Import/ConversationDraftBuilder.swift
- Trace/Features/Conversation/ConversationImportView.swift
- Trace/Features/Conversation/ScreenshotOrderView.swift
- Trace/Features/Conversation/ParticipantMappingView.swift
- Trace/Features/Conversation/MessageReviewView.swift

工作：

- OCR 保存文字、confidence、bounding box 與 engine revision。
- raw OCR 改為唯讀；修改只寫 confirmed transcript。
- 多張附件建立 ConversationGroup 並允許拖曳 orderIndex。
- 先以左側、右側、系統訊息建立候選 MessageSegment。
- 詢問哪一側是使用者；人物角色不由系統推測。
- 支援一般、引用、系統、附件與無法辨識訊息類型。
- 每段訊息可播放原圖定位、修改、確認或標記不確定。
- 全部必要欄位確認後，才可建立正式事件 revision。

驗收：

- 多圖排序、人物映射、日期與訊息確認可中途離開後繼續。
- 原圖、原始 OCR 與確認稿能同時追溯。
- 裁切、遮罩與未知日期不會被拒絕，但會保留狀態。
- 未確認訊息不會被 AI 或案件摘要當作事實。

建議 commits：

- Preserve immutable OCR observations
- Add ordered conversation groups and participant mapping
- Add message-by-message confirmation flow

### W5：可見式錄音與原始音檔

目標：使用者可主動開始、暫停、繼續及停止錄音，完成後形成不可覆寫的 audio attachment。

修改：

- Trace/Resources/Info.plist
- Trace/Views/CaptureView.swift
- Trace/Views/EventDetailView.swift
- Trace/Views/RootView.swift

新增：

- Trace/Services/Audio/AudioRecorderService.swift
- Trace/Services/Audio/AudioSessionCoordinator.swift
- Trace/Services/Audio/AudioInterruption.swift
- Trace/Features/Recording/RecordingView.swift
- Trace/Features/Recording/RecordingViewModel.swift
- Trace/Features/Recording/RecordingRecoveryView.swift

工作：

- 新增 NSMicrophoneUsageDescription。
- AudioRecorderService 以 actor 管理單一錄音 session。
- 使用 AVAudioSession 與 AVAudioRecorder 產生 m4a。
- UI 持續顯示錄音、暫停、經過時間及停止。
- App 離開 active 時依規格暫停並完成檔案，不啟用背景音訊模式。
- 監聽來電、Siri、route change、耳機拔除與 media services reset。
- 錄音寫入 staging；停止後 close、取得 duration、雜湊並原子保存。
- App 被終止後，下次啟動可辨識未完成錄音並讓使用者保存或刪除。
- 錄音完成後可關聯新事件、既有事件或先留在待整理材料。

驗收：

- 權限允許、拒絕與之後從設定開啟都有正確 UI。
- 開始、暫停、繼續、停止狀態不可跳號。
- 來電或音訊路由改變不產生無法管理的檔案。
- 完成音檔可播放、雜湊、刪除、備份及匯出。
- 畫面與 VoiceOver 都能辨識錄音狀態。

建議 commits：

- Add visible foreground audio recording
- Handle interruptions and recover unfinished recordings

### W6：SpeechAnalyzer／SpeechTranscriber

目標：支援裝置產生裝置端分段逐字稿，其他裝置保留完整手動流程。

修改：

- Trace/Resources/Info.plist
- project.yml

新增：

- Trace/Services/Speech/SpeechTranscribing.swift
- Trace/Services/Speech/SpeechAvailability.swift
- Trace/Services/Speech/SpeechAnalyzerService.swift
- Trace/Services/Speech/ManualTranscriptService.swift
- Trace/Features/Transcription/TranscriptionView.swift
- Trace/Features/Transcription/TranscriptReviewView.swift
- Trace/Features/Transcription/TranscriptionViewModel.swift

工作：

- 新增 NSSpeechRecognitionUsageDescription。
- 以 @available(iOS 26.0, *) 隔離 SpeechAnalyzerService。
- 檢查 SpeechTranscriber.isAvailable 與 supported locale。
- 以 AssetInventory 顯示 unsupported、supported、downloading、installed。
- 音檔分析以 AsyncSequence 接收結果，支援取消與重新執行。
- 保存 raw transcript、時間分段、confidence、locale 與 engine version。
- 修正內容另存 confirmed transcript，不修改 raw result。
- 長音檔顯示進度；取消後保留原音檔及已完成狀態，不建立假完成稿。
- iOS 17～25 或不支援語系時提供手動逐字稿與事件問答。

驗收：

- 支援裝置完成「音檔 → 逐字稿 → 分段播放 → 確認」。
- 資產未下載時顯示下載狀態，不顯示一般失敗。
- 重跑轉錄建立新 SpeechTranscript。
- 原始逐字稿不可被 UI 修改。
- 舊裝置不載入 iOS 26 class、不崩潰且可手動完成。

建議 commits：

- Add speech capability and asset availability
- Add immutable segmented transcription
- Add manual fallback for unsupported devices

### W7：Apple Intelligence 結構化事件

目標：將已確認文字整理成可審閱的事件草稿，不做霸凌或法律判定。

新增：

- Trace/Services/Intelligence/IntelligenceDrafting.swift
- Trace/Services/Intelligence/IntelligenceAvailability.swift
- Trace/Services/Intelligence/FoundationModelsService.swift
- Trace/Services/Intelligence/FixedQuestionDraftService.swift
- Trace/Services/Intelligence/PromptCatalog.swift
- Trace/Services/Intelligence/EventDraft.swift
- Trace/Features/Intelligence/IntelligenceSourcePickerView.swift
- Trace/Features/Intelligence/IntelligenceDraftView.swift
- Trace/Features/Intelligence/IntelligenceViewModel.swift

工作：

- 以 @available(iOS 26.0, *) 隔離 Foundation Models。
- 檢查 SystemLanguageModel availability 與 locale。
- 實作 EventDraft guided generation。
- 固定 instructions 要求中性、不推測動機、不作法律結論。
- 只允許 confirmed OCR、confirmed transcript 與既有 revision 作輸入。
- 使用者來源文字只放 prompt，不插入 instructions。
- 產生前顯示來源清單；使用者明確確認後才送入模型。
- 串流 partial snapshot 只供 UI，不寫入正式事件。
- 完整輸出保存為 IntelligenceDraft，逐欄接受、修改或拒絕。
- App 驗證 sourceReferences 必須對應實際輸入來源。
- 接受後建立 EventRevision source confirmedAI。
- 模型不可用時使用相同欄位的固定問答服務。
- 保存 prompt version、OS/model version、locale、來源 ID 與結果狀態。

驗收：

- 不支援裝置、AI 未開啟、model not ready 與語言不支援各有明確狀態。
- 未確認來源無法進入模型。
- 拒絕草稿不改動任何來源。
- 接受草稿建立新 revision，保留 AI 標記及來源。
- 匿名 fixture 不把未知動機、人物、時間或法律結論寫成事實。
- prompt injection fixture 不改變固定 instructions。

建議 commits：

- Add Apple Intelligence availability and fallback
- Generate source-traceable structured event drafts
- Add AI draft review and acceptance flow

### W8：多事件 PDF／ZIP 案件包

目標：輸出專業人士可以理解、並能驗證原始附件完整性的案件包。

修改：

- Trace/Services/PDFExporter.swift
- Trace/Views/EventDetailView.swift

新增：

- Trace/Services/Export/CasePackageExporter.swift
- Trace/Services/Export/CasePackageManifest.swift
- Trace/Services/Export/AttachmentNumbering.swift
- Trace/Services/Export/ZIPArchiveService.swift
- Trace/Features/Export/CaseSelectionView.swift
- Trace/Features/Export/CasePackagePreviewView.swift

工作：

- 允許選擇一件或多件事件。
- 建立案件總覽、時間線、事件詳情、對話頁、語音逐字稿頁與附件索引。
- AI 內容必須標示產生時間、prompt version 與使用者確認狀態。
- 原始附件重新驗證 SHA-256；mismatch 或 missing 阻擋完整包並顯示原因。
- ZIP 包含 PDF、原始附件及 manifest.json。
- manifest 保存 export ID、版本、附件編號、相對路徑、byteCount、SHA-256 與時間。
- PDF 自身也計算 SHA-256 並寫入 manifest。
- 大量附件支援進度、取消、暫存清理及重試。

驗收：

- PDF 與 manifest 的附件編號一致。
- ZIP 每個檔案可依 manifest 重新驗證。
- 未確認、推估與 AI 協助內容有清楚標示。
- 原始音檔與截圖保持原 bytes。
- 取消匯出不留下 orphan Exports。

建議 commits：

- Build multi-event case PDF
- Export originals and manifest as verified case package

### W9：隱私、備份、安全與診斷

目標：新資料模型與附件流程可安全鎖定、備份、還原、刪除及回報錯誤。

修改：

- Trace/Services/AppLockManager.swift
- Trace/Services/BackupService.swift
- Trace/Views/RootView.swift
- Trace/Views/PrivacyView.swift
- Trace/Views/BackupView.swift

新增：

- Trace/Services/Security/PrivacyShieldController.swift
- Trace/Services/Backup/BackupFormatV2.swift
- Trace/Services/Backup/BackupRestoreCoordinator.swift
- Trace/Services/Diagnostics/DiagnosticExporter.swift

工作：

- scene 進入 inactive 即顯示不含敏感資料的 privacy shield。
- background 時鎖定 session，active 先遮罩再驗證。
- Backup v2 包含 schema version、全部原始附件、revision、OCR、逐字稿與 AI 草稿。
- 還原先解密到 staging，逐檔驗證後以 transaction 寫入。
- 錯密碼、損壞、空間不足與中斷不得留下部分資料。
- 診斷只含 App、OS、裝置能力、匿名錯誤碼與 operation 狀態。
- 診斷不得包含事件、OCR、逐字稿、prompt、response、姓名、檔名或雜湊。
- 提供「刪除全部 App 資料」並說明外部備份不會被刪除。

驗收：

- App Switcher 截圖不顯示事件或附件。
- Backup → 刪除本機 → Restore 後資料與原始附件雜湊一致。
- 錯密碼與損壞備份資料庫仍為原狀。
- 完整刪除後重啟無資料、無檔案、無暫存。
- 匯出的診斷檔不含 fixture 文字。

建議 commits：

- Add app switcher privacy shield
- Upgrade encrypted backup to schema v2
- Add safe diagnostics and complete data deletion

### W10：TestFlight 外部測試

目標：完成簽署、真機、隱私文件、回饋與版本發布。

修改：

- project.yml
- Trace/Resources/Info.plist
- README.md
- .github/workflows/ios-build.yml

新增：

- docs/PRIVACY_POLICY_DRAFT.md
- docs/BETA_TESTER_GUIDE.md
- docs/RELEASE_CHECKLIST.md
- docs/KNOWN_ISSUES.md

工作：

- 設定 Apple Developer Team。
- 在 Developer Portal 註冊 group.tw.dayi.trace。
- 主 App 與 Share Extension 使用相同 App Group entitlement。
- 設定正式版本號、build number 與 archive。
- 完成 Onboarding：用途、資料位置、錄音提醒、AI 限制與備份風險。
- 完成隱私政策、測試條款、聯絡與回饋入口。
- 回饋入口預設不附帶事件內容。
- 建立 Threads 招募文案與支援裝置篩選。
- 完成 App Store Connect Beta App Review Information。

真機矩陣：

| 裝置 | 目的 |
|---|---|
| iOS 17～25 iPhone | 舊裝置完整手動流程與 API 隔離 |
| iOS 26、無 Apple Intelligence | Speech／AI availability 降級 |
| iOS 26、支援 Apple Intelligence | 完整錄音、轉錄、AI 與案件包 |
| 第二種螢幕尺寸 | Dynamic Type、版面與錄音控制 |

External Beta Gate：

- M0～M4 規劃 Gate 全部通過。
- 沒有資料遺失、誤刪、未授權分享或不可恢復孤兒檔。
- 支援裝置完成錄音 → 逐字稿 → AI 草稿 → 事件 → 案件包。
- 不支援裝置完成手動整理 → 事件 → 案件包。
- 測試者能正確說明哪些資料留在裝置、何時產生匯出檔。

建議 commits：

- Add beta onboarding privacy and tester documentation
- Prepare signed External Beta candidate

## 6. 測試與驗證方式

目前工作環境是 Windows，無法在本機執行 Xcode 或 iOS Simulator。實作時使用四層驗證：

1. Windows：檔案結構、語法靜態檢查、資料 fixture、Git diff。
2. GitHub Actions macOS：XcodeGen、Xcode 26 build、Unit Tests。
3. Mac／Simulator：主要 UI flow、migration、匯入與輸出。
4. 實體 iPhone：錄音、Speech assets、Apple Intelligence、Face ID、App Group 與 Data Protection。

每個工作包至少要有：

- 正常流程測試。
- 使用者取消測試。
- 權限或能力不可用測試。
- 中斷或 App 重啟測試。
- 資料不完整或損壞測試。
- 完整刪除測試。

## 7. Prompt 評估集

Apple Intelligence 不以「看起來合理」作為驗收。建立匿名固定資料集：

- 單一明確工作指令。
- 缺少日期或人物。
- 同一事件有矛盾說法。
- 帶有情緒但無具體行為。
- 多事件混在同一逐字稿。
- 引用內容與實際發言混合。
- 要求模型判定霸凌或違法。
- 來源文字包含「忽略前面指示」等 prompt injection。

每筆輸出檢查：

- 結構是否完整。
- 是否漏掉重要具體行為。
- 是否新增來源不存在的事實。
- 是否把推估寫成確定。
- 是否產生法律結論。
- source references 是否全部可驗證。
- 補問是否中性且不超過三個。

## 8. Pull Request 與提交策略

每個工作包使用獨立 branch 與可回滾 commit，branch 建議使用 codex/trace-wN-名稱。不要把 schema migration、錄音、AI 與 PDF 放在同一個巨大 PR。

每個 PR 必須包含：

- 對應工作包與規格章節。
- 資料格式或 migration 影響。
- 新增與更新測試。
- simulator／真機驗證範圍。
- 已知限制。
- 隱私與敏感資料影響。

合併順序固定為 W0 → W1 → W2；W3／W4 與 W5／W6 可在資料底座完成後分支開發，W7 必須等待兩邊的 confirmed source contract 穩定。

## 9. 外部依賴與使用者需準備事項

不阻擋前期寫程式，但 TestFlight 前必須具備：

- Apple Developer Program 帳號與 Team ID。
- 可註冊的 Bundle IDs 與 App Group。
- 一台支援 Apple Intelligence 的 iPhone。
- 一台不支援 Apple Intelligence 或較舊 iOS 的 iPhone。
- 可公開的隱私政策 URL。
- 測試用、已匿名化的 LINE 截圖與會議音檔。
- TestFlight 測試者聯絡與回饋管道。

禁止把真實職場事件直接提交到 Git、Issue、CI log 或測試 fixture。

## 10. 第一個實作批次

第一批只做 W0～W2，目標是建立後續功能可信任的底座：

1. 新增 Unit/UI test targets 與 CI test。
2. 建立 VersionedSchema 與 migration fixture。
3. 原始 EventRevision、OCRResult 唯讀化。
4. 重寫 EvidenceStore 為 staging＋atomic move。
5. 建立完整性重驗與完整刪除服務。
6. 修正目前直接編輯 raw OCR、直接刪資料及 try? 吞錯的 UI。

第一批完成定義：

- 現有事件與附件仍可正常開啟。
- V1 → V2 migration 自動化測試通過。
- 原始陳述與 raw OCR 無法被覆寫。
- 新附件寫入具備原子性及雜湊驗證。
- 刪除附件與事件不留下檔案。
- GitHub Actions build 與 unit tests 全綠。

完成第一批後，才開始聊天截圖與錄音兩條功能線。

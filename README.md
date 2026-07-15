# 留痕 Trace iOS

留痕是給員工使用的日常工作事件安全日誌。它保存原始附件、整理 OCR／逐字稿，讓使用者在需要時輸出可核對的 PDF 事件包；它不會自動判定「是否構成職場霸凌」，也不取代律師、工會或主管機關的判斷。

## 目前已實作

- SwiftData V2 資料模型與 V1→V2 migration 底座。
- 原始附件 staging、原子寫入、SHA-256 完整性驗證、操作日誌與完整刪除／回復。
- Photos、Files 與 Share Extension 匯入圖片；原始截圖不可覆寫。
- Vision 本機 OCR、聊天來源／截圖狀態／哪一側是本人確認，以及訊息排列草稿。
- 可見的麥克風錄音流程；停止後才保存音檔，不提供隱蔽錄音。
- iOS 26+ 可選的 SpeechAnalyzer／SpeechTranscriber 音檔轉錄。
- iOS 26+ 可選的 Foundation Models 結構化事件草稿；結果必須由使用者確認。
- PDF 事件包：事件摘要、版本、附件 SHA-256、完整性、圖片縮圖與確認後 OCR／逐字稿。
- Face ID／Touch ID App Lock、App Group Share Extension 與單元測試。

## 開發環境

- Xcode 26.5（SpeechAnalyzer 與 Foundation Models 需要 iOS 26 SDK）。
- Deployment target：iOS 17；iOS 17 可使用核心記錄、附件、OCR 與 PDF，iOS 26 才顯示 Apple Speech／Intelligence 功能。
- 需要 macOS、Apple Developer Team、App Group `group.tw.dayi.trace` 才能在真機測試與發佈。

```bash
brew install xcodegen
xcodegen generate
open Trace.xcodeproj
```

## 驗證

GitHub Actions 會以 iPhone 17 Simulator 執行編譯與 `TraceTests`。目前 `main` 已通過最新一輪 build 與單元測試。

## 隱私與證據原則

錄音必須由使用者主動按下開始，畫面會明確顯示錄音狀態與 iOS 麥克風指示。原始檔、OCR 結果、AI 草稿與使用者確認版本分開保存；AI 只能整理材料，不能把推測寫成事實或法律結論。

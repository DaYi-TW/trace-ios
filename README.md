# Trace iOS

「留痕 Trace」是以員工自保為目的的私密工作事件整理工具。它不判定職場霸凌，也不讀取 LINE 或其他聊天 App 的帳號資料；使用者主動匯入的材料保留在裝置上，再整理成事件包 PDF。

## 目前可測試的流程

1. 建立工作事件。
2. 從相簿匯入聊天截圖或從 Files 匯入文件。
3. 保存原始檔、雜湊與匯入時間。
4. 對圖片執行裝置端 OCR，並讓使用者確認結果。
5. 將事件匯出為 PDF 摘要。
6. 從 iOS 分享選單將截圖交給「加入留痕」Share Extension，回到 App 後自動建立待整理事件。
7. 使用 Face ID／Touch ID／裝置密碼保護開啟畫面，並建立或還原密碼加密的完整備份。

## 在 Mac 上開啟

本專案使用 XcodeGen 產生 Xcode 專案，以避免提交由 Xcode 自動產生的大型專案檔。

```bash
brew install xcodegen
xcodegen generate
open Trace.xcodeproj
```

在 Xcode 選取你的 Development Team 後，以 iOS 17 以上的模擬器或真機執行。真機測試前必須驗證：相簿權限、檔案保護、PDF 分享、不同 LINE 截圖版面及繁體中文 OCR。

## 尚未產品化的功能

- SpeechAnalyzer 事後口述轉錄。
- Foundation Models 結構化整理。
- 對話跨圖去重、長圖拼接與自動遮罩。

SpeechAnalyzer 與 Foundation Models 須在核心流程的 TestFlight 回饋成立後逐項加入；分享擴充、App Group、Face ID 和備份則必須先在真機完成簽署、還原與資料保護測試。

## 首次真機設定

1. 在 Apple Developer 與 Xcode 的兩個 target 啟用同一個 App Group：`group.tw.dayi.trace`。
2. 在兩個 target 選取相同的 Development Team，讓 provisioning profile 包含 App Groups。
3. 加入實際的 1024×1024 App Icon 後，才可上傳 TestFlight。

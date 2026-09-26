# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [0.1.1-zhtw.1] - 2026-09-26

zh-TW fork of upstream 0.1.1（koshian-plugins commit 36c904d）。

### Added

- `lib/condense-sessions.mjs`：把 session JSONL 濃縮成只剩真人輸入、assistant 文字、工具摘要與錯誤；
  跳過已處理、沒有真人輸入、headless／SDK 與結晶化本身的 session；遮罩 secret（含專案 `.env` 的實際值）
- `config.md` 的 `existing_rules`：每次全文讀取的比對基準
- `include_headless` 設定、`processed-sessions.txt`、`<nfd-dir>/tmp/`（不進 git，跑完刪除）
- 報告新增「矛盾」一節（規則與實際行為的落差、過時描述）、每個模式的「狀態」欄（新發現／需補強／已存在）、「評估備註」

### Changed

- 全部翻成繁體中文
- session 紀錄改由濃縮腳本處理，取代「每個 JSONL 讀末尾 2000 行」
- `/nfd-init` 預設把 NFD 目錄寫進 `.git/info/exclude`，改 `.gitignore` 變成選項
- 明確禁止把中間檔寫到 `/tmp` 等共用位置
- 註明 headless 執行要用 `Edit(<nfd-dir>/**)` 開放寫入

## [0.1.1] - 2026-03-14

### Fixed

- NFD 目錄路徑從寫死改成動態解析（參照 `config.md` 的 `nfd_dir`）
- 釐清雙工作區的說明（認知脈絡分離 ≠ 檔案系統分離）
- 修正 `plugin.json` 的 `repository` 為正確的 marketplace repo

## [0.1.0] - 2026-03-14

Initial release.

### Added

- `/nfd-init` 指令 — 在專案建立 NFD 基礎（建目錄、產生初始檔案、初始化獨立 Git repo）
- `/nfd-help` 指令 — 診斷 NFD 工作流程狀態並說明下一步
- `crystallize` skill — 從經驗資料萃取模式的 8 步驟結晶化流程
- NFD 方法論參考（`documents/nfd-methodology.md`）
- 雙工作區模式的說明（釐清認知脈絡分離）
- 防過度擬合與必須人工驗證
- 支援 session 紀錄、auto memory、NFD trace、claude-mem MCP 等資料來源

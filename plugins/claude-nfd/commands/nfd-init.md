---
description: 在專案建立 NFD（Nurture-First Development）工作流程的基礎
allowed-tools: Read, Write, Edit, Bash(git:*,mkdir:*,ls:*,test:*,cat:*,touch:*), Glob, Grep, AskUserQuestion
argument-hint: [nfd-dir-path]
---

# 建立 NFD 基礎

在專案建立 NFD（Nurture-First Development）的基礎目錄與檔案。

## 步驟

### Step 1：決定 NFD 目錄路徑

有指定參數 `$ARGUMENTS` 就用它，沒有就用預設的 `.nfd`。
以下把這個路徑寫成 `<nfd-dir>`。

### Step 2：確認既有 NFD 環境

確認 `<nfd-dir>` 是否已存在。

- 已存在：用 AskUserQuestion 問「找到既有的 NFD 目錄，要覆蓋嗎？」。使用者拒絕就中止。
- 不存在：繼續。

### Step 3：建立目錄結構

```
<nfd-dir>/
├── traces/       # 經驗 trace（依 6 個類別標籤）
├── crystals/     # 結晶化報告
├── metrics/      # 量測資料（將來用）
└── tmp/          # 結晶化的暫存（濃縮後的 session 紀錄），不進 git，每次跑完刪除
```

`traces/`、`crystals/`、`metrics/` 各放一個空的 `.gitkeep`。

### Step 4：產生初始檔案

#### `<nfd-dir>/.gitignore`

```
tmp/
```

#### `<nfd-dir>/processed-sessions.txt`

空檔案。結晶化處理過的 session id 會一行一個附加在這裡。

#### `<nfd-dir>/README.md`

```markdown
# NFD（Nurture-First Development）

這個目錄是管理 NFD 工作流程經驗資料的獨立 repo。

## 目錄

- [目錄結構](#目錄結構)
- [用法](#用法)
- [經驗 trace 的 6 個類別](#經驗-trace-的-6-個類別)

## 目錄結構

- `traces/` — 經驗 trace（每個 session 零碎的想法）
- `crystals/` — 結晶化報告（萃取出的模式）
- `metrics/` — 量測資料（將來用）
- `tmp/` — 結晶化暫存，不進 git
- `config.md` — 資料來源設定
- `crystallization-log.md` — 結晶化進度紀錄
- `processed-sessions.txt` — 已處理的 session id

## 用法

### 日常工作（培育工作區）

- 照常開發。經驗會自動累積（session 紀錄、auto memory）
- 有想法可以手動記到 `traces/`

### 跑結晶化（外科工作區）

建議在**跟日常工作不同的 session** 執行。

1. 開新 terminal 或新 session，執行 `/crystallize`
2. 結果輸出到 `crystals/`
3. 看報告，把有用的模式在日常 session 整合成規則或 skill

## 經驗 trace 的 6 個類別

| 類別 | 標籤 | 記錄什麼 |
|------|------|---------|
| 操作紀錄 | `[operational]` | 決定與動作的事實 |
| 推理軌跡 | `[reasoning]` | 判斷背後的邏輯與前提 |
| 模式觀察 | `[pattern]` | 反覆發生的事件的共同點 |
| 失敗原因 | `[error]` | 錯誤的根本原因與修正步驟 |
| 脈絡註記 | `[context]` | 專案背景或團隊特有的方針 |
| 洞見片段 | `[insight]` | 還沒整理、但將來可能重要的想法 |
```

#### `<nfd-dir>/crystallization-log.md`

```markdown
# 結晶化紀錄

記錄結晶化的執行歷史與各資料來源的處理位置。

## 處理位置

為了增量處理，記錄每個資料來源上次處理到哪裡。

| 資料來源 | 最後處理位置 | 最後處理日 |
|---------|-------------|-----------|
| （未設定） | — | — |

## 執行歷史

<!-- 每次結晶化用以下格式追加 -->
<!-- ### YYYY-MM-DD 第 N 次結晶化 -->
<!-- - 輸入來源: ... -->
<!-- - 萃取模式數: N -->
<!-- - 輸出: crystals/YYYY-MM-DD-crystallization.md -->
```

#### `<nfd-dir>/config.md`

先看專案裡實際存在哪些規則與教訓文件，把存在的寫進 `existing_rules`（常見的有 `AGENTS.md`、`CLAUDE.md`、
`app/*/AGENTS.md` 這類子目錄文件、`.claude/rules/`、`docs/LESSON.md`）。

```markdown
---
nfd_dir: <nfd-dir 的實際路徑>
data_sources:
  # 自動收集（預設開啟）
  traces: <nfd-dir>/traces/
  auto_memory: true                  # Claude Code 標準的 auto memory（MEMORY.md + memory/）
  session_logs: true                 # Claude Code 的 session 紀錄（JSONL），經濃縮腳本處理
  include_headless: false            # true 時也分析 headless／SDK 自動化的 session

  # 選用（外部工具）
  session_data: false                # 用 claude-mem MCP 時改成 true

  # 專案自訂（可自由新增）
  custom:
    # 例:
    # decision_log: docs/decisions/
    # retrospectives: docs/retro/

# 既有規則：每次都全文讀取，用來去重、找矛盾與過時的描述
existing_rules:
  # - AGENTS.md
  # - CLAUDE.md
  # - app/*/AGENTS.md
  # - .claude/rules/
  # - docs/LESSON.md
---

# NFD 設定

## 資料來源

結晶化的輸入來源，在上面的 YAML frontmatter 設定。

### 自動收集

- **traces**：NFD trace 目錄（預設 `<nfd-dir>/traces/`）
- **auto_memory**：是否使用 Claude Code 標準的 auto memory（預設 `true`）
  - 讀專案的 `MEMORY.md` 與 `~/.claude/projects/<project>/memory/` 裡的檔案
- **session_logs**：是否使用 Claude Code 的 session 紀錄（預設 `true`）
  - `~/.claude/projects/<project>/*.jsonl`，由 plugin 的 `lib/condense-sessions.mjs` 濃縮後分析
  - 濃縮時會遮罩 secret、跳過雜訊 session
- **include_headless**：是否納入 headless／SDK 的 session（預設 `false`，這類多半是自動化工具）

### 選用（外部工具）

- **session_data**：是否使用 claude-mem MCP 的 session 資料（預設 `false`）

### 專案自訂來源

在 `custom` 加 `名稱: 路徑`。路徑相對於專案根目錄。

### 既有規則

`existing_rules` 列出的檔案每次都會全文讀取，作為比對基準：
已經寫在裡面的模式標成「已存在」，跟實際行為不符的列為「矛盾」。
```

### Step 5：初始化獨立 Git repo

在 `<nfd-dir>` 執行 `git -C "<nfd-dir>" init`，把初始檔案全部 add 並 commit：

```bash
git -C "<nfd-dir>" add -A
git -C "<nfd-dir>" commit -m "Initial NFD setup"
```

### Step 6：讓上層 repo 忽略 NFD 目錄

NFD 資料是個人的經驗資料（含對話摘錄），不放進上層 repo。

確認上層 repo 是否已忽略 `<nfd-dir>`（`git check-ignore -q "<nfd-dir>"`）。還沒忽略的話，用 AskUserQuestion 問：

- **只在這台機器忽略（建議）**：寫進 `.git/info/exclude`。不改動被追蹤的檔案，不會產生 commit
- **寫進 `.gitignore`**：團隊成員都會忽略，但會改動被追蹤的檔案
- **不忽略**

### Step 7：建議下一步

完成後回報：

1. 建立的目錄與檔案
2. 下一步建議：
   - 「確認 `config.md` 的 `existing_rules` 列的是這個專案實際的規則與教訓文件，需要時加上專案自訂來源」
   - 「已經有經驗資料的話，可以在新的 session 執行 `/crystallize` 做第一次結晶化（為了避免認知干擾，建議不要在日常工作 session 裡跑）」
   - 「日常開發的想法可以記在 `traces/`」

## 注意

- Git 指令一律用 `git -C "<nfd-dir>"`，對 NFD repo 操作，不要動到上層 repo
- 不要用 `cd`
- 路徑有空白要用雙引號

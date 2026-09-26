---
name: crystallize
description: This skill should be used when the user asks to "crystallize", "結晶化", "萃取模式", "整理經驗", "分析 session 紀錄", "跑 KCC", "run crystallization", "extract patterns from experience", "convert traces to skills", "analyze session data for patterns", "run KCC", or mentions knowledge crystallization, NFD crystallization cycle, or pattern extraction from operational data. Provides a structured 8-step process for extracting reusable knowledge from experiential data.
---

# Knowledge Crystallization（知識結晶化）

NFD（Nurture-First Development）的核心流程。分析日常開發累積的零碎資料，轉成可重複使用的結構化知識（模式、規則、skill）。

產出的是「**怎麼做事**」的知識（流程、踩坑、慣例），不是功能點子、也不是記憶。
記憶系統負責「記得」，結晶化負責把經驗**升級成專案規則**，並抓出規則與實際行為的落差。

## 前提

- 專案已用 `/nfd-init` 建好 NFD 基礎（`<nfd-dir>/config.md` 存在）
- `config.md` 已設定資料來源

## 在「外科工作區」執行（建議）

依 NFD 的雙工作區模式，結晶化要在**跟日常工作不同的 session** 執行。
在日常工作中跑，大量資料會灌進 context，干擾 AI 的推理（認知干擾）。

**建議做法：**

1. **開新 session**（最簡單）：新開 terminal 啟動 `claude`，執行 `/crystallize`。同一個目錄就可以
2. **git worktree**（隔離更嚴格）：`git worktree add ../<project>-nfd nfd-work` 分出工作副本，在那邊跑

**headless 執行**（`claude -p`）時，檔案寫入權限要用 `Edit(<nfd-dir>/**)`；`Write(...)` 規則不會套用到檔案權限檢查，報告會寫不進去。
濃縮腳本需要 `Bash(node:*)`，session 紀錄目錄在專案外，要加 `--add-dir ~/.claude/projects/<project>`。

**結晶化之後的整合（每週～每月）：**

1. 看結晶化報告（`crystals/YYYY-MM-DD-crystallization.md`）
2. 挑要整合的模式
3. 回到日常工作 session 整合：
   - 規則：寫進專案的 `AGENTS.md`／`CLAUDE.md`，或 `.claude/rules/<rule-name>.md`
   - skill：`.claude/skills/<skill-name>/SKILL.md`
   - 踩坑：專案既有的教訓文件（例如 `docs/LESSON.md`）
4. 整合後確認行為，再 commit 到專案 repo

結晶化的產出會自動 commit 到 NFD repo。要回滾就 `git -C <nfd-dir> log` 看歷史、`git -C <nfd-dir> revert <commit>`。

## 結晶化的 8 個步驟

### Step 1：讀設定、確認處理位置

1. 讀 NFD 設定檔（`config.md`），從 YAML frontmatter 取得資料來源路徑
2. 從 `crystallization-log.md` 確認上次的處理位置
3. 增量處理：只處理上次之後的新資料

找不到設定檔時，從專案根目錄依序找：
1. `.nfd/config.md`（預設路徑）
2. Glob `**/config.md`，找有 `nfd_dir` frontmatter 的檔案

以找到的 `config.md` 裡 `nfd_dir` 的值作為 `<nfd-dir>`，之後所有路徑都以它為準。

### Step 2：收集資料

| 來源 | 收集方式 | 未處理的判定 |
|------|----------|-------------|
| **NFD trace**（`traces`） | Read `traces/` 裡的檔案 | 比紀錄的最後處理檔名更新的檔案 |
| **auto memory**（`auto_memory`） | Read 專案的 `MEMORY.md` 與 `~/.claude/projects/<project>/memory/` | MEMORY.md 更新時間比紀錄新 |
| **session 紀錄**（`session_logs`） | **用濃縮腳本**（見下方「session 紀錄的收集」），不要直接 Read JSONL | 腳本以 `processed.txt` 排除已處理的 session |
| **session 資料**（`session_data`） | claude-mem MCP 的 `smart_search` | 紀錄的最後處理日之後 |
| **自訂來源**（`custom`） | 依路徑 Read／Glob | 紀錄的最後處理日之後有更新的檔案 |
| **既有規則**（`existing_rules`） | Read 全部 | 每次都讀全文——這是比對基準，不是分析對象 |

**重要：**
- auto memory 與 session 紀錄是 Claude Code 的標準功能，大多數專案都有，是第一次結晶化最有用的來源
- claude-mem MCP 不可用時，跳過 session 資料，用其他來源繼續，不要當成錯誤
- **既有規則**（專案的 `AGENTS.md`、`CLAUDE.md`、`.claude/rules/`、教訓文件）一定要讀：Step 5 的去重與矛盾檢查靠它

完全找不到資料就回報後結束。

### Step 3：平行萃取（subagent）

資料夠多（有多個來源，或濃縮檔超過約 15 萬字）時，用 Agent 工具最多開 3 個 subagent 平行分析，
把濃縮檔依日期分批交給它們。

**每個 subagent 的指示範本：**

```
分析以下資料，用 NFD 的 6 個類別分類並萃取模式。

## 6 個類別
- [operational] 操作紀錄：決定與動作的事實
- [reasoning] 推理軌跡：判斷背後的邏輯與前提
- [pattern] 模式觀察：反覆發生的事件的共同點
- [error] 失敗原因：錯誤的根本原因與修正步驟
- [context] 脈絡註記：專案背景或團隊特有的方針
- [insight] 洞見片段：還沒整理、但將來可能重要的想法

## 輸出格式
每個模式寫：
1. 類別標籤
2. 模式名稱（簡短）
3. 觀察內容（引用具體案例，附 session id 前 8 碼）
4. 抽象化的原則（去除專案專有資訊：公司名、產品名、人名、特定 URL 等換成通用說法）
5. 證據強度（單一案例／多個證據／已確立），寫出幾個 session 出現過
6. 建議動作（規則化／skill 化／持續觀察）

## 分析對象
<濃縮檔路徑清單>
```

只有一個來源且量不大時，不用 subagent，直接分析。

### Step 4：整合與去重

1. 合併相同或相似的模式
2. 多個來源都確認的模式，提高證據強度
3. 依證據強度排序（已確立 > 多個證據 > 單一案例）

### Step 5：防過度擬合、去脈絡化、比對既有規則

- **單一案例規則**：只從 1 個案例導出的模式加上 `[待觀察]`，不要立刻規則化
- **脈絡依賴檢查**：強烈依賴特定函式庫／版本／環境的模式，寫明限制
- **已存在檢查**：每個模式都對照 `existing_rules`。已經寫在裡面的，標成「**已存在於 <檔案>**」，
  只記這次的新證據，**不要當成新發現**
- **矛盾檢查**：跟既有規則衝突、或**規則寫了但實際行為常常沒照做**的，列為「矛盾」並附證據。
  這類落差通常比新模式更有價值
- **過時檢查**：既有文件描述的行為跟程式碼或最近 commit 不符的，也列為「矛盾」
- **去脈絡化**：模式描述裡有專案專有名稱（公司名、產品名、人名、特定 URL、內部系統名）就換成通用說法，
  但不要改到失去原本的意思
- **不引用 secret**：濃縮檔裡的 `***` 是遮罩；報告裡不要還原或推測被遮的值

### Step 6：輸出結晶化報告

輸出到 `crystals/`：

**檔名**：`YYYY-MM-DD-crystallization.md`（同一天第二次加 `-2`）

**格式：**

```markdown
# 結晶化報告 — YYYY-MM-DD

## 概要
- 分析的資料來源：（列出）
- 萃取的模式數：N（新發現 A／需補強既有文件 B／已存在 C）
- 其中建議規則化或 skill 化：M
- 其中待觀察：K
- 與既有規則矛盾：X 處

## 矛盾（先處理）

### 矛盾 1：標題
- 既有規則怎麼寫（檔案:行）
- 實際發生什麼（證據：session id、commit）
- 推測原因
- 建議（需要人決定的地方寫清楚）

## 模式一覽

### 1. [類別] 模式名稱

| 項目 | 內容 |
|---|---|
| 觀察 | 具體案例 |
| 原則 | 抽象化後的知識 |
| 證據強度 | 單一案例／多個證據／已確立（N 個 session） |
| 狀態 | 新發現／需補強：<檔案>／已存在於 <檔案> |
| 建議動作 | 規則化／skill 化／持續觀察 |
| 整合位置 | 建議寫進哪個檔案 |

## 建議動作一覽

### 規則化候選
### skill 化候選
### 持續觀察

## 評估備註
- 各資料來源實際讀了多少（檔案數、濃縮後字數、跳過幾個及原因——直接貼濃縮腳本的摘要表）
- 哪些模式是既有規則沒有的新東西
- 資料涵蓋率的限制（例如有多少 commit 找不到對應 session）
```

### Step 7：更新紀錄、清理暫存、Git commit

1. 更新 `crystallization-log.md` 的處理位置表：

```markdown
| 資料來源 | 最後處理位置 | 最後處理日 |
|---------|-------------|-----------|
| traces | <最後處理檔名> | YYYY-MM-DD |
| auto_memory | <MEMORY.md 最後更新時間> | YYYY-MM-DD |
| session_logs | 見 `processed-sessions.txt`（N 個 session） | YYYY-MM-DD |
| custom:<名稱> | <最後處理檔名／時間> | YYYY-MM-DD |
```

2. 把這次保留的 session id 附加到 `<nfd-dir>/processed-sessions.txt`（每行一個完整 id）
3. 追加執行歷史
4. **刪除暫存**：`rm -rf <nfd-dir>/tmp`（濃縮檔含對話內容，不留）。**不要把中間檔寫到 `/tmp` 或其他共用位置**
5. commit 到 NFD repo：

```bash
git -C "<nfd-dir>" add -A
git -C "<nfd-dir>" commit -m "Crystallization: YYYY-MM-DD — N patterns extracted"
```

**重要**：用 `git -C` 明確指定 NFD 目錄，不要 commit 到上層 repo。不要用 `cd`。

### Step 8：回報結果、等人確認

回報：

1. **矛盾**（有的話放最前面）
2. **萃取結果摘要**（數量與最重要的 3～5 個）
3. **建議動作**（標出建議規則化或 skill 化的）
4. **下一步**：「請看結晶化報告（`crystals/YYYY-MM-DD-crystallization.md`），挑好要整合的模式再告訴我」

**一定要人工確認**：不可以自動把結果整合進規則或 skill。一定要等使用者確認並明確指示。

**給使用者的確認重點：**
- 這個模式跟你的經驗相符嗎？
- 有沒有過度一般化？或太特殊？
- 跟既有規則有沒有衝突？
- 規則化或 skill 化之後，會不會在未來的 session 造成傷害？

## session 紀錄的收集

`session_logs: true`（預設）時：

1. 用 plugin 附的濃縮腳本產生濃縮檔（在專案根目錄執行）：

```bash
node "${CLAUDE_PLUGIN_ROOT}/lib/condense-sessions.mjs" \
  --out "<nfd-dir>/tmp/sessions" \
  --processed "<nfd-dir>/processed-sessions.txt"
```

2. 腳本做的事：
   - 讀 `~/.claude/projects/<project>/*.jsonl` 的**完整內容**（不是只讀末尾）
   - 只留真人輸入、assistant 文字、工具呼叫摘要、工具錯誤；丟掉附件、檔案快照、mode 等雜訊紀錄
   - **跳過**：已處理的 session、沒有真人輸入的、headless／SDK 自動化（`entrypoint: sdk-cli`，例如記憶壓縮工具）、
     結晶化本身的 session。要納入 headless 加 `--include-headless`
   - 單一 session 超過 `--max-chars`（預設 40000 字）時，真人輸入與錯誤全部保留，其餘保留頭 25%／尾 75%，中間標示省略
   - **遮罩 secret**：專案 `.env`／`.env.local` 的實際值、`sk-…`、`Bearer …`、`xc-token`、`*_KEY=`／`*_TOKEN=` 等
   - stdout 印一張摘要表（每個 session 保留或跳過、原因），貼進報告的「評估備註」
3. 分析 `<nfd-dir>/tmp/sessions/*.md`，不要再直接 Read 原始 JSONL

session 紀錄是最豐富的來源，涵蓋全部 6 個類別：
- `[operational]`：工具呼叫與結果
- `[reasoning]`：Claude 的判斷過程
- `[error]`：錯誤發生時的處理模式
- `[context]`：使用者的指示與回饋
- `[pattern]`：反覆出現的工作流程
- `[insight]`：對話中產生的想法

## auto memory 的收集

`auto_memory: true`（預設）時：

1. 專案根目錄有 `MEMORY.md` 就 Read
2. Glob `~/.claude/projects/<project>/memory/` 裡的檔案並 Read
3. 跟其他來源一樣納入分析

auto memory 也要做**矛盾檢查**：memory 的寫法可能讓 agent 誤以為某件需要授權的事是例行步驟。

## claude-mem MCP（選用）

`session_data: true` 且 claude-mem MCP 可用時：

1. 用 `smart_search` 找專案相關的近期 session 資料
2. 用 `timeline` 看特定期間的活動
3. 跟其他來源一樣納入分析

不可用時靜靜跳過，不要警告。

## 注意

- 8 個步驟是系統化的框架，但每一步「要萃取什麼、要留什麼」重質不重量，只挑真的有重用價值的模式
- 隨時確認跟既有規則的一致性
- Git 指令一律用 `git -C "<nfd-dir>"`
- 報告與回報用使用者的語言（專案規則指定的語言優先）

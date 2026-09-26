---
description: 診斷 NFD 工作流程目前的狀態，告訴你下一步該做什麼
allowed-tools: Read, Glob, Grep, Bash(test:*,ls:*,git:*,wc:*,head:*,tail:*), AskUserQuestion
---

# NFD 說明 — 狀態診斷與下一步

自動診斷 NFD 工作流程目前的狀態，告訴使用者下一步該做什麼。

## 步驟

### Step 1：找到 NFD 目錄並確認狀態

依序找，第一個找到的當作 `<nfd-dir>`：

1. 確認 `.nfd/config.md` 是否存在
2. 不存在的話，Glob `**/config.md` 找有 `nfd_dir` frontmatter 的檔案

找到後讀 `config.md` 的 `nfd_dir`，之後所有路徑都以它為準。

接著檢查以下項目並判斷狀態：

1. **config.md 的設定**：讀 YAML frontmatter，確認資料來源與 `existing_rules` 的設定
2. **crystallization-log.md 與執行歷史**：以前有沒有跑過結晶化
3. **traces/ 的內容**：有沒有累積手動 trace
4. **crystals/ 的內容**：有沒有結晶化報告
5. **獨立 Git repo**：`<nfd-dir>` 裡有沒有 `.git`
6. **暫存殘留**：`<nfd-dir>/tmp/` 還在的話，代表上次結晶化中途失敗，提醒刪除（裡面是對話摘錄）

### Step 2：依狀態輸出說明

依診斷結果，從下列情況選一個：

---

#### 情況 A：還沒導入（找不到 NFD 目錄）

```
## NFD 狀態：未導入

這個專案還沒有 NFD 基礎。

### 下一步
1. 執行 `/nfd-init` 建立基礎
2. 在產生的 `config.md` 設定資料來源與 `existing_rules`

### NFD 是什麼？
一種「培育」AI agent 的開發方法。定期把日常開發經驗結晶化（萃取模式），
升級成規則或 skill，持續改善 AI 的回應品質。

詳見：documents/nfd-methodology.md（plugin 內附的參考文件）
論文：https://arxiv.org/abs/2603.10808
```

---

#### 情況 B：已建立、還沒設定（config.md 的資料來源維持預設、`existing_rules` 是空的）

```
## NFD 狀態：已建立（建議設定）

NFD 基礎已建立，但設定還是預設值。

### 目前啟用的資料來源
- ✅ auto memory（MEMORY.md + memory/）
- ✅ session 紀錄（JSONL，經濃縮）
- ✅ NFD trace（<nfd-dir>/traces/）
- ❌ 既有規則（existing_rules 未設定 → 無法判斷「已存在」與「矛盾」）
- ❌ 自訂來源（未設定）
- ❌ claude-mem MCP（未啟用）

### 下一步
1. 在 `<nfd-dir>/config.md` 的 `existing_rules` 列出專案的規則與教訓文件
   （例如 AGENTS.md、CLAUDE.md、.claude/rules/、docs/LESSON.md）
2. **開新 terminal** 啟動 `claude`（避免認知干擾），執行 `/crystallize`
```

---

#### 情況 C：已設定、還沒跑過結晶化（crystallization-log.md 沒有執行歷史）

```
## NFD 狀態：已設定（建議第一次結晶化）

NFD 基礎與設定都完成了，來跑第一次結晶化吧。

### 已設定的資料來源
（讀 config.md 列出）

### 下一步
1. **開新 terminal** 啟動 `claude`（外科工作區）
2. 執行 `/crystallize`
3. 看報告，把有用的模式整合成規則或 skill
```

---

#### 情況 D：跑過結晶化（crystals/ 有報告）

```
## NFD 狀態：運作中 ✓

### 結晶化執行歷史
（讀 crystallization-log.md 顯示）

### 最新的結晶化報告
（顯示最新的 crystals/*.md 檔名）

### 下一步
- **看報告**：讀最新報告，確認有沒有該整合的模式，尤其是「矛盾」一節
- **下次結晶化**：累積新經驗後再跑 `/crystallize`（每週～每月）
- **記錄 trace**：日常工作中有想法可以記到 `<nfd-dir>/traces/`

### 運作提示
- 結晶化在**另一個 session** 跑（避免認知干擾）
- 把模式整合成規則或 skill 前，一定要跟自己的經驗對照
- 不要只憑 1 個案例就訂規則（防過度擬合）
```

---

#### 情況 E：最新報告裡有還沒整合的建議

除了情況 D，再讀最新的結晶化報告，確認「矛盾」「規則化候選」「skill 化候選」有沒有內容。有的話加上：

```
### ⚠ 有還沒整合的模式
最新的結晶化報告（crystals/YYYY-MM-DD-crystallization.md）裡
有建議整合的項目，請確認後考慮整合：

（簡短列出矛盾、規則化候選、skill 化候選的名稱）
```

---

### Step 3：顯示快速參考

不管哪個情況，最後都顯示：

```
### NFD 快速參考

| 指令／操作 | 說明 |
|-----------|------|
| `/nfd-init` | 建立 NFD 基礎 |
| `/crystallize` | 把經驗結晶化（建議在另一個 session 跑） |
| `/nfd-help` | 顯示這份說明 |
| `<nfd-dir>/config.md` | 資料來源與既有規則的設定 |
| `<nfd-dir>/traces/` | 手動 trace 的存放處 |
| `<nfd-dir>/crystals/` | 結晶化報告的輸出處 |

### NFD 的 3 層結構
- **憲法層**：AGENTS.md／CLAUDE.md + .claude/rules/ — 根本原則
- **skill 層**：.claude/skills/ — 針對特定任務的 skill
- **經驗層**：session 紀錄 + auto memory + trace — 每天的累積
         ↑ 用 /crystallize 把經驗升級到 skill 層
```

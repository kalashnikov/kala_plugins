---
name: check
description: >-
  產出 feature-ideas vault 的狀態摘要。以實數統計件數（類別別、狀態別、紀錄表），
  偵測被放著爛掉的項目（重新評估逾期、長期未確認、混進 vault 目錄的 plan 或 spec、
  沒人引用的詳細檔、index 與 ADR 不一致）。
  被問「點子進度怎樣」「想確認進度」「想盤點」「有沒有被放著的」「接下來該做什麼」時，
  以及版本里程碑或大功能剛完成後，一定要啟動。
  發想新點子時不用（用 feature-ideation 本體）。深入單一項目也不用
  （用 feature-ideation discuss ID）。不改寫 vault，只做回報。
argument-hint: "[vault 路徑]"
allowed-tools: Bash(bash "${CLAUDE_PLUGIN_ROOT}/lib/vault-digest.sh":*), Read, Grep, Glob
shell: bash
---

# vault 狀態確認

**這個 skill 完全不改寫檔案。** 工作範圍是回報事實、提出選項。回報一律用**繁體中文（台灣用語）**。

## 統計結果（機器產生）

以下是 `lib/vault-digest.sh` 的執行結果，不是模型產生的。

````
!`bash "${CLAUDE_PLUGIN_ROOT}/lib/vault-digest.sh" $ARGUMENTS || true`
````


## 鐵則

1. **不自己數。** 件數直接照抄 `-- COUNTS --`。不可寫 digest 裡沒有的數字
2. **不自己算日期。** 經過天數直接用 digest 的值。不要換成「最近」「前陣子」
3. **不擅自修正。** 發現放置或矛盾只回報。要 archive 還是補連結由使用者決定
4. **不捏造 digest 裡沒有的 ID**

## 怎麼讀 digest

| 行 | 意義與處理 |
|---|---|
| `digest_status: no-vault` | 沒有 vault。不談件數，引導「不帶參數啟動 `/feature-ideation` 從發想開始吧」後結束 |
| `digest_status: degraded` | 拿不到今天日期。日期類警示不可信，只回報件數並註明 |
| `vault_candidates:` | 找到多個 vault。說明看的是哪個，不對就請使用者指定路徑重跑 |
| `legacy_note:` | 有舊格式（`A-1` 等）ID 的行。**件數不含這些**。先講這件事並建議遷移，再談件數 |
| `overdue` | 重新評估佇列逾期。**機器已斷定，直接列出** |
| `LOOSE_OVERDUE` | 內文寫的絕對日期期限。可建議移到佇列 |
| `due_soon` | 7 天內到期 |
| `stale_sweep` / `stale_category` / `STALE_PROBING` | 整體 / 類別 / 個別項目長期未確認 |
| `frozen` | 等待觸發條件。**不是逾期，不要混在一起回報** |
| `ledger_incomplete` | 紀錄表的 `證據` 或 `心得` 是空的。從實作回到 vault 的路徑斷了 |
| `FOREIGN` | 違反 vault 目錄命名規則的檔案。附 `plan` / `spec` / `unknown` 分類 |
| `ORPHAN` | index 和其他詳細檔都沒引用 |
| `MISSING_DETAIL` | index 有連結但檔案不存在 |
| `XREF` | index 的 ID 被 ADR / plan / CHANGELOG 提到。**進行下方的核對** |
| `DANGLING` | 外部提到的 ID 不在 index。可能漏登錄 |
| `PICK_TRIGGER` | 優先挑選的改選條件成立 |
| `PARSE WARNINGS` | 違反書寫規範。**件數可能有偏差，一定要告知** |

## 模型的工作（只有這裡需要判斷）

### 1. 核對 `XREF` — index 跟上實況了嗎

digest 只把「index 的行」和「外部文件的提及」並列，不判斷哪邊對。
日期相同內容也可能矛盾。

每個 `XREF` 行都 Read 外部文件的對應處，與 index 的行比對。有出入就
**具體寫出哪裡怎麼不同**。不要只說「status 過時」
（例：「index 寫『候選 2〜4 未判定』，但 ADR-0011 在 2026-07-25 已把候選 3 設為 Accepted」）。
可以提修正建議但不執行。

### 2. 分類 `FOREIGN` / `ORPHAN`

零引用不等於異物。Read 檔案開頭，分成 3 類：

- **異物** — plan / spec / 調查筆記。建議移動位置（plan → `docs/plans/`、spec → `docs/specs/`、決策紀錄 → ADR）
- **漏連結** — 是正當的詳細檔但父層沒連。建議補連結
- **孤立的結論** — 寫了結論卻沒反映到 index。**最危險**。建議反映到 index

### 3. 「接下來要動手的話」3 項

從 `-- ROWS --` 以效益 大 × 難度 低〜中 × 限制 ✅ 為起點選 3 項。
不是算分排序，而是每項用 1 行寫**為什麼是現在做這個**。可綁在一起的輕量項目算一格。

**「前提變化」（依賴對象已發布等）的驗證不在這裡做。**
需要外部確認的只列出來，引導使用 `/feature-ideation discuss ID`。

## 輸出範本

```markdown
## Vault 摘要 — <vault path> (<today>)

**最後更新** <date>（N 天前） / **最後盤點** <last_sweep>

### ⏰ 待處理
（0 項就明寫「沒有被放置的項目」。不要整段省略）

| 種類 | 對象 | 內容 | 經過 |
|---|---|---|---|

### 件數
- open N 項（類別別：...）
- 狀態別：...
- 紀錄表：已實作 N 項 / 不採用 N 項
- 詳細檔：N 個（其中異物 N 個）

### 🔀 index 與實作・決策的出入
### 🗂 vault 目錄整潔度
### 🎯 接下來要動手的話
### 下一步
```

警示 0 項的區段也**不要省略，寫「無」**。省略的話，使用者分不出是確認過還是忘了。

## digest 沒有送達時

只在 digest 區塊是空的或明顯壞掉時，從上往下嘗試，**成功就停**。

1. 用 Bash 工具執行 `bash "${CLAUDE_PLUGIN_ROOT}/lib/vault-digest.sh"`
2. 還是失敗的話，**先**告知「bash 無法使用，改為人工統計，件數精確度會下降」，
   再用 Read 和 Glob 讀 vault。輸出開頭一定加上警告
3. 任何階段都**不要把推測的數字當成機器統計結果**

## 反模式

- **跳過 digest 重新 Read vault** — 白做工，還會數錯
- **把 digest 數字四捨五入成「約 20 項」** — 照實數寫
- **默默刪掉 0 項警示的區段** — 無法和漏檢區分
- **用「status 過時」一句話帶過 `XREF`** — 不寫哪裡怎麼不同，使用者最後還是得兩邊都讀，
  這個 skill 的價值就沒了
- **把 `frozen` 當成逾期回報** — 等待觸發條件沒有期限。混在一起就成了放羊的孩子

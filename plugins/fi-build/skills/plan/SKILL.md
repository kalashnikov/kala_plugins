---
name: plan
description: 為 feature-ideation vault 裡一個要動工的 FI 寫實作計畫：先摸清會動到的程式碼，再決定資料形狀與邊界，能實測的分岔用丟棄式腳本跑出結果，最後寫成 plan 檔並停下等使用者說 go。只在使用者打 /fi-build:plan FI-NNN 時啟動。不寫正式程式碼。
argument-hint: "FI-NNN"
disable-model-invocation: true
---

# fi-build plan

把一個 FI 從「決定要做」帶到「可以照著做的 plan」。**這個 skill 的產出是 plan 檔，不是程式碼。** 寫完就停。

改寫自 pstack（poteto）的 how、architect、prototype playbook，只保留單一 Claude session 用得到的部分。

## 0. 確定對象

1. 找 vault index：專案的 `docs/feature-ideas.md`（或 feature-ideation 設定的路徑）。找不到該 ID 就說「`FI-NNN` 不在 vault」並**中止**，不要猜相似的 ID。
2. Glob `<vault 目錄>/FI-NNN*.md`，有詳細檔就整份讀。
3. 讀 vault 的「與既有文件的分工」表，找 plan 放哪（通常 `docs/plans/`）與命名慣例（看該目錄最新幾個檔名）。
4. 狀態是 `idea` 又沒有詳細檔時，提醒一次「建議先 `/feature-ideation discuss FI-NNN`」，然後**照樣繼續**，不擋。
5. 讀專案的 `AGENTS.md`／`CLAUDE.md` 驗證與部署段落，plan 的 Verify 要用專案自己的指令。

開 todo：摸清、形狀、實測、寫 plan、回報。

## 1. 摸清會動到的程式碼（how）

目標：讓下一個沒看過這段程式的 agent 也能建立正確心智模型。**只列檔名不算摸清。**

- repo 有 graft／codebase-memory 等索引就先用（`graft ask`、`graft callers <sym> --depth 2`），沒有再 grep。
- 範圍大（跨 3 個以上模組、前後端都動）時，開 1–3 個 `Explore` subagent 各查一個面向，只收 `file:line` 與結論，不收整段程式碼。小範圍自己查。
- FI 的「備註」「詳細檔」說已經有的東西（例如「已有 4／8 週靜態尾巴」）**一定要找到實際程式碼確認**，寫出 `file:line`。說法與程式不符時，以程式為準並在 plan 記下落差。

整理出：

- **資料從哪來**：API／Redis key／DB 表、格式、實際存量（筆數、時間深度）。外部資料一律假設可能缺值。
- **目前怎麼流**：入口 → 計算 → 顯示，每一段一個 `file:line`。
- **誰會被影響**：要改的共用函式有哪些呼叫端。
- **坑**：查 `LESSON.md`／`docs/lessons/`、相關記憶有沒有記過同區域的坑。

## 2. 決定形狀（architect）

**先寫呼叫端怎麼用，再推出型別。** 先寫出使用的樣子（元件 props、函式呼叫、API 回傳的 JSON 範例），型別與模組切法從那裡推。

- **資料形狀**：寫出核心型別或 JSON 範例。能用一張表／registry／狀態機取代一堆分散的 if，就用結構。
- **邊界**：外部資料在哪一層解析與檢查；之後的內部程式信任型別，不再到處防禦。
- **至少想兩個結構不同的形狀**（整體做法不同，不是同一做法的小變化）。用 [`references/design-red-flags.md`](references/design-red-flags.md) 篩。差異不影響決策時，被否決的方案一行帶過；真的有取捨才列比較表。
- **先減再加**：有沒有可以先刪掉或合併的舊路徑、重複清單、只有一個呼叫端的包裝。有就排在 plan 前面。
- **能放進既有共用模組就放進去**，不新開平行的第二套。

## 3. 能實測的分岔就實測（prototype）

遇到「該用哪種做法」的問題，先分類：

- **答案是可以跑出來的事實**（效能、資料夠不夠、畫面密度、時序、公式結果）→ 不問使用者。在 scratchpad 寫最小的丟棄式腳本或 HTML 跑出結果，用結果決定。腳本不進 repo，不寫測試、不做抽象。
- **答案是產品偏好**（要不要、長怎樣比較喜歡、預設值）→ 列在 plan 的「待你決定」，給選項與建議。

每個實測都記下：問什麼、怎麼跑、結果（數字或截圖路徑）、因此決定什麼。數字要過 verify 的 [`number-checklist`](../verify/references/number-checklist.md) 第 4、7 題（有沒有錯誤、工作真的有跑）。

## 4. 寫 plan

照 [`references/plan-template.md`](references/plan-template.md) 寫進 plan 目錄，檔名依專案慣例（例如下一個 `PLAN_0NN_<SLUG>.md`）。

- 一個步驟 = 一個可以單獨驗證的小單位。每一步都要有 **Files／Build／You see／Verify**。
- Verify 寫專案真實指令與真實對象（dev server 頁面、production build、正式網域、實際 API 回應），不寫「確認正常」這種話。
- 有數字的步驟（回測、績效、效能）在 Verify 指名要過 number-checklist。
- 改到共用模組的步驟，在 Verify 指名要做 blast-radius（verify skill 的步驟 3）。
- 不寫部署步驟細節，只寫「部署照 `docs/OPERATIONS.md`」之類的指引；部署一律等使用者。

## 5. 更新 vault（只改這三處）

1. index 該行狀態改 `planned`，備註換成一行摘要＋plan 連結。
2. 有詳細檔就在 `## 判定歷程` 追加一行：`- YYYY-MM-DD fi-build plan → <plan 路徑>（形狀：一句話）`。沒有詳細檔就不建。
3. **plan 不放進 vault 目錄**，詳細檔也不寫 `- [ ] Step` 形式的步驟。

## 6. 回報後停下

回報內容：

- plan 路徑
- 摸清時發現的事實與落差（含 `file:line`），特別是 vault 說法與程式不符的地方
- 選定的形狀與一句理由；有比較表就附
- 實測做了什麼、結果、因此決定什麼（scratchpad 路徑）
- **待你決定**的產品問題，每題附建議
- 步驟數與預估難度

最後一句固定是：「看過沒問題說 go 就開始實作；實作完用 `/fi-build:verify FI-NNN` 驗證。」

**不要自己開始實作。** 使用者說 go 之前不改 repo 的程式碼。

## 不要做的事

- 用記憶或 vault 備註取代讀程式碼
- 為了「彈性」加沒被要求的設定或抽象
- 把可以跑出來的問題丟給使用者決定
- 在 plan 寫「確認沒問題」「測試通過」這類沒有對象的驗證
- 動到 vault 狀態、備註、判定歷程以外的地方

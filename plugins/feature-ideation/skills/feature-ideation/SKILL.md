---
name: feature-ideation
description: >-
  廣泛發想專案的功能候選，存進 Markdown vault，依效益、難度、與專案限制的相容性打標籤，
  讓優先度一目了然。當使用者說「有什麼點子嗎？」「有沒有可以改善的地方」「想腦力激盪功能」
  「類似工具有這種功能」這類、在進入單一功能設計之前的廣泛發想時，一定要啟動。
  也負責既有點子的深入研究 (discuss) 與完成・放棄的整理 (archive)。
  若已在細化單一功能規格，用 superpowers:brainstorming；查看 vault 狀態用 check。
argument-hint: "[discuss ID | archive ID 理由]"
---

# Feature Ideation

負責「決定要做哪個功能」之前的階段。廣泛列出點子，依效益、難度、與專案限制的相容性打標籤，
保存到 `docs/feature-ideas.md`（或使用者指定路徑）的 vault。

**語言**：vault 內容與對話一律使用**繁體中文（台灣用語）**。區段標題與欄名必須照
[`references/template.md`](references/template.md) 逐字使用，`check` 靠它們統計。

**分工**：要做的東西已經決定一個、正在細化規格，用 `superpowers:brainstorming`。
還沒決定要做什麼就用本 skill。拿不準就先用本 skill 定方向再交出去。

## 依參數分流

| 參數 | 動作 |
|---|---|
| （無） | 執行下方「預設流程」 |
| `discuss ID` | 讀 [`references/discuss.md`](references/discuss.md) 並照做 |
| `archive ID [理由]` | 讀 [`references/archive.md`](references/archive.md) 並照做 |
| 其他 | 告知「請用 `discuss` / `archive`，或不帶參數啟動」並中止 |

vault 狀態確認（件數、逾期、停滯）不由本 skill 處理，而是 **`check` skill**。
被問「進度如何？」「想盤點一下」時引導到那邊。

---

## 預設流程

已有 vault 就**先 Read 再開始**。

### 1. 探索專案

目的是**掌握現況、限制、非目標**。偷懶的話點子會停在「有了方便」，
還會白白量產牴觸專案 value prop 的提案。

只讀存在的：`CLAUDE.md` / `README.md` / `TODO.md` / `ROADMAP.md` / `docs/plans/` /
`package.json`・`Cargo.toml`・`go.mod` 等 / **既有 vault**（為避免重複新增，一定要讀）。

**特別要找**：明確的**非目標、借用判斷原則、value prop**。像「維持單一執行檔」
「不依賴外部服務」「可離線運作」這類不變條件，是之後 `⚠️` / `❌` 判定的依據。
沒寫明就從 README 的價值主張與既有技術選型推測。

目前 effort 是 `${CLAUDE_EFFORT}`。若為 xhigh 或 max，擴大探索範圍，讀到設計文件與
測試，具體掌握限制的依據。

### 2. 選類別軸

依專案類型定 **5〜8 個**。太少點子會薄，太多排列的工夫會超過收穫。

建議預設（可重組）：核心品質強化 / 周邊整合・客戶端特化 / 輸入與支援範圍多樣化 /
品質與維運基礎 / UX 小改 / 從其他工具引進的候選 / 研究型題材。
依專案性質可加上資安、i18n、無障礙、onboarding 等。

### 3. 產生點子

每個類別以 **5〜10 項**為目標。想不出來的類別 2〜3 項也行，不要硬湊。
評估軸的意義與打標籤方式見 [`references/evaluation.md`](references/evaluation.md)。

目前 effort 是 `${CLAUDE_EFFORT}`。若為 xhigh 或 max，每個類別換不同視角深挖
（程式碼痛點 / 競品功能 / 維運漏洞 / 使用者的原話）。

**外部事實要在這個 session 當場查證。** 「類似工具 X 有這功能」「benchmark 改善 N%」
這類外部事實不能憑模型記憶寫。記憶中的功能清單可能過時或根本不存在。
用 WebSearch / WebFetch 確認並**留下 URL**。確認不了就不寫，或明寫「未確認」。
vault 是長期參考的資產，而且點子的性質讓它事後很少被驗證。這裡混進的錯誤會留很久。

### 4. 推薦挑選

列出 **「接下來要動手的話」個人押注順序** 5〜7 項，每項附一句為什麼是這個順序。
可綁在一起的輕量功能合成一項也可以。
同時列出 **「刻意延後」** 2〜3 項，附理由。

### 5. 對齊方向（在這裡停一次）

用 `AskUserQuestion` 問：

- 哪些類別 / 項目有感覺（複選）
- 動機比較接近哪個 — 自己用得順手 / 想給別人用 / 具體卡住了 / OSS 式的差異化

使用者只指定類別沒講動機，也可以直接往下走。

### 6. 保存

**已有檔案**：merge。避開 ID 衝突，把新項目加到對應類別，
帶日期更新優先挑選。**尊重既有類別編排與 ID，不擅自改編**。

**沒有檔案**：以 [`references/template.md`](references/template.md) 為樣板建立。
填入專案不變條件、分工表、類別表。ID 從 `FI-001` 連續編號。

### 7. 提出下一步

只列選項。等使用者選。

- 推薦第一名進入設計階段（有 `superpowers:writing-plans` 就交給它，沒有就走一般設計流程）
- 對某個 ID 用 `discuss` 深入
- 在 `TODO.md` 加一行互相連結
- 直接停下（使用者沒指定就選這個）

---

## 一定要遵守

- **不擅自進入實作階段。** 這個 skill 只建 vault。step 7 可以提案，
  但使用者選之前，程式碼和計畫都不寫
- **不憑記憶寫外部事實。** 查證並留 URL（step 3）
- **不破壞性改寫既有 vault。** 既有 ID 是被紀錄表、ADR 引用的外部鍵，不改編
- **條件觸發型的遺留事項不放 vault。** 「出現〜時」「驗證〜之後」無法換成日期，
  寫成期限的當下就注定沒人注意而被放著。處理方式見
  [`references/archive.md`](references/archive.md) 的「隔離條件觸發事項」
- **下游動了就回來更新 index。** 寫了 ADR、做成 plan、實作了 — 那時也要更新 vault 的行。
  實際發生過從 GO 判定到實作完成只花 2 小時，index 上卻維持「未判定」好幾週的案例

## 反模式

- **類別粒度不均** — 一個類別 20 項、其他只有 1 項，代表切分不好。平均到 5〜10
- **沒有依據的評分** — 只寫「效益 大」沒理由價值很低。在備註加一行
- **非得全覆蓋症候群** — 硬把所有類別填滿，就會排出一堆薄弱點子
- **備註無上限** — 超過 200 字就升級為詳細檔（[`references/evaluation.md`](references/evaluation.md)）
- **覆寫評價** — 像 `⚠️` → `✅` 這樣判定變動時，不要刪舊評價，帶日期追加到詳細檔的
  `## 判定歷程`。覆寫的話，將來會再討論一次同樣的事

## 參考

- 評估軸意義、升級標準、詳細檔格式 → [`references/evaluation.md`](references/evaluation.md)
- `discuss` 步驟 → [`references/discuss.md`](references/discuss.md)
- `archive` 步驟與 2 張歸檔表格式 → [`references/archive.md`](references/archive.md)
- vault 範本與 `check` 的統計契約 → [`references/template.md`](references/template.md)

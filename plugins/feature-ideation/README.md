# feature-ideation（繁體中文版）

Fork 自 [koshian-plugins/feature-ideation](https://github.com/alphabet-h/koshian-plugins/tree/master/plugins/feature-ideation) v0.1.4（commit 227fdeb），MIT。

## 它解決什麼問題

「點子一直累積，但沒人回頭看」。所有點子存在專案裡的一個 Markdown 檔 `docs/feature-ideas.md`（稱為 vault），依效益、難度、是否違背專案原則打標籤，讓優先度一目了然；再用腳本定期盤點，找出被放著爛掉的項目。

## Vault 的結構

- 按類別分成 5–8 張表。每個點子一行，欄位是：ID、狀態、名稱、效益（大/中/小）、難度（低/中/高/極高）、是否違背專案原則（✅/⚠️/❌）、備註。
- ID 用 `FI-001` 這種流水號，一旦編了就不改，因為其他文件會引用它。
- 狀態只有 4 種：`idea`（還沒動）、`probing`（深入研究中）、`planned`（已寫計畫、交給實作流程）、`frozen`（等某個條件發生才處理）。
- 做完或放棄的點子，整行移到檔尾的「已實作紀錄」或「不採用紀錄」。已實作的一定要附證據（PR、commit）和心得。
- 某個點子的備註超過 200 字，就獨立成 `docs/feature-ideas/FI-NNN.md`。

## 日常用法

| 什麼時候 | 做什麼 |
|---|---|
| 想到新點子 | 先寫進清單底部的「待整理」，決定可能會做時再編號放進類別表。也可以問「有什麼點子？」讓它再發想一輪 |
| 想動手做某項之前 | `/feature-ideation discuss FI-013`：用問答把這項想清楚，內容多就另開詳細檔 |
| 做完或決定不做 | `/feature-ideation archive FI-001 完成`：移到紀錄表 |
| 每週檢查一次 | `/feature-ideation:check`：腳本實際計數，列出逾期、太久沒看、放錯位置的項目，推薦下一步 3 項 |
| 想自動提醒 | `/schedule` 設每週跑 check，或 `/loop 7d /feature-ideation:check` |

check 只回報不改檔，清單也不會在 session 開始時自動載入，要自己打指令。

## discuss 不是 spec refinement

discuss 問的是「值不值得做、在什麼條件下做」，是進入規格之前的那一關。它從 5 個方向挑最有用的 2–3 題來問（⚠️→✅ 的升級條件、實作入口、影響範圍、比較對象、驗證方式），外部事實當場用 WebSearch 查並留 URL，結果寫回備註或詳細檔的「判定歷程」，最後停下來給選項，不會自己開始寫程式。

| | discuss | grill-me | superpowers brainstorming |
|---|---|---|---|
| 要回答的問題 | 值不值得做、在什麼條件下做 | 計畫還有哪些地方沒想清楚 | 具體要怎麼做 |
| 問得多深 | 淺，2–3 題 | 深，一題一題追到底 | 深，一次一題，並提出 2–3 種做法 |
| 產出 | 清單一行或詳細檔 | 對計畫的共同理解 | 設計規格 → writing-plans |

完整流程：feature-ideation（發想、排序）→ discuss（決定做不做）→ brainstorming 或 grill-me（細化規格）→ writing-plans → 實作 → archive（附 PR 和心得結案）。

## 何時不用 / 注意

- 一個專案一份，適合長期維護的專案，不適合集中管理所有零散點子。
- 已經在細化單一功能規格時，用 superpowers:brainstorming，不用它。
- 專案裡已經有其他待辦清單時，要先寫清楚誰管什麼（例如研究假設留在原清單、產品功能放 vault），不然會變成多份清單並存。
- 區段標題與欄名是 check 的統計契約，不能改名。

## 原作者的設計理由

- ID 不帶類別意義，因為類別重組時 ID 會失準。
- 已實作紀錄的證據和心得欄禁止留空，強迫從實作連回 vault。
- 無法換成日期的「條件式延後」移出 vault，否則寫了期限也沒人注意。
- 計數交給 shell 腳本，不讓模型估。

## 與原版的差異

- skill 與 references 全部翻成繁中；vault 的區段標題與欄名改用繁中（狀態/名稱/效益/難度/限制/備註、重新評估佇列、優先挑選、已實作紀錄、不採用紀錄、待整理、變更紀錄、最後確認）。
- `lib/vault-digest.sh` 同時認得繁中和日文標題，日文 vault 仍可用；輸出訊息改繁中。用 upstream 10 組測試資料比對，計數與原版完全相同。
- 修正 macOS bug：`sort | uniq` 在 UTF-8 locale 下把「中、大、小」視為同一字，效益和類別計數全部擠在一起。修法是 `LC_COLLATE=C`。
- 修正 macOS bug：內建 bash 3.2 在 `$( )` 裡解析 `case pattern)` 時，把 `)` 當成替換結尾，DETAIL DIR 區段會印出原始碼片段，缺檔偵測從未生效。修法是改寫成 `(pattern)`。
- 範本規則編號勘誤：「見更新規則 8-10」改為規則 6。

上面兩個 macOS bug upstream 也有，尚未回報。

## 相容性

`vault-digest.sh` 只用 bash、awk、git、find、mktemp、sort、uniq；`stat` 同時支援 GNU 與 BSD 寫法。同一份 vault 在 macOS（bash 3.2）與 Ubuntu（bash 5.2 + mawk）的輸出逐位元組相同。

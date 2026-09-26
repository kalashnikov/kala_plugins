# claude-nfd（繁體中文版）

Fork 自 [koshian-plugins/claude-nfd](https://github.com/alphabet-h/koshian-plugins/tree/master/plugins/claude-nfd) v0.1.1（commit 36c904d），MIT。

## 它解決什麼問題

規則寫了，agent 卻沒照做；做事的慣例大家都在遵守，卻從來沒寫下來；文件描述的行為早就改掉了。
這些落差藏在 session 紀錄裡，人工整理時很難看出來。

`/crystallize` 讀 session 紀錄、auto memory 與手動 trace，萃取「**怎麼做事**」的模式，
再跟專案既有的規則文件逐條比對，分成：

- **矛盾**：規則寫了但實際常沒照做、文件描述已經過時
- **新發現**：規則文件裡沒有的慣例或踩坑
- **需補強**：既有規則寫得不夠完整
- **已存在**：已經寫過，只記錄這次的新證據

結果寫成報告，**不會自動改任何規則**，由人挑選後再整合進 `AGENTS.md`、`.claude/rules/` 或 skill。

方法出自 Linghao Zhang 的論文 [Nurture-First Agent Development](https://arxiv.org/abs/2603.10808)（2026 年 3 月）。
細節見 [方法論參考](documents/nfd-methodology.md)。

## 跟其他工具的分工

| | 回答的問題 | 產出去哪 |
|---|---|---|
| 記憶系統（auto memory、OpenViking 等） | 之前發生過什麼、決定了什麼 | 記憶，執行時注入 |
| **claude-nfd** | 我們**怎麼做事**才不會出錯；規則跟實際有沒有落差 | 報告 → 人工整合進規則、skill、教訓文件 |
| [feature-ideation](../feature-ideation) | 接下來**要做什麼** | 點子 vault |

它不是功能點子的來源：實測兩份報告共 44 個模式，幾乎都是流程、git、部署、驗證這類做事方式，
能變成功能點子的只有兩三個工具類候選。

## 實測（2026-09，一個跑了一個月的 Next.js 專案）

| | 機器 A | 機器 B |
|---|---|---|
| 資料 | 4 個有效 session（另 16 個 headless 雜訊） | 30 個 session，60 MB 濃縮到約 37 萬字 |
| 模式 | 20 個（11 個新發現） | 24 個（12 個新發現、5 個需補強） |
| 最有價值的發現 | 某目錄文件描述的行為在一個月前就被 commit 拿掉了（拆檔時原樣搬過去，人工沒發現） | 規則寫「部署前先問」，但 9 個 session 沒問就重啟；原因是 memory 把指令寫在最前面，讀起來像例行步驟 |

第二個例子說明它跟記憶系統是互補的：造成問題的正是那條記憶，而記憶系統本身不會發現「記憶跟規則互相矛盾」。

## 安裝

```
/plugin marketplace add kalashnikov/kala_plugins
/plugin install claude-nfd@kala
```

跟原版 `claude-nfd@koshian-plugins` 的指令與 skill 同名，**只能啟用其中一個**。

## 用法

```
/claude-nfd:nfd-init          # 建立 .nfd/（獨立 git repo），預設只在本機忽略
/claude-nfd:nfd-help          # 看目前狀態與下一步
/crystallize                  # 在「另一個」session 跑
```

1. `/nfd-init` 後，確認 `.nfd/config.md` 的 `existing_rules` 列的是專案實際的規則與教訓文件
2. 開新 terminal，執行 `/crystallize`（每週～每月一次）
3. 看 `.nfd/crystals/YYYY-MM-DD-crystallization.md`，先處理「矛盾」，再挑要整合的模式
4. 回到日常 session，把挑好的模式寫進規則或 skill

### headless（排程或一次對多台機器跑）

```bash
claude -p "/crystallize" \
  --add-dir "$HOME/.claude/projects/<project>" \
  --allowedTools "Read" "Glob" "Grep" "Agent" "Edit(.nfd/**)" "Bash(node:*)" "Bash(git -C .nfd:*)" "Bash(rm -rf .nfd/tmp)"
```

寫入權限要用 `Edit(...)`；`Write(...)` 規則不會套用到檔案權限檢查，報告會寫不進去。

## 與原版的差異

- 全部翻成繁體中文
- **session 紀錄改由 `lib/condense-sessions.mjs` 濃縮**。原版「每個 JSONL 讀末尾 2000 行」實測失效：
  單檔常常不到 2000 行卻有好幾 MB，直接讀會塞爆 context；只讀末尾也會丟掉開頭的需求。
  腳本讀完整檔案，只留真人輸入、assistant 文字、工具摘要與錯誤，單一 session 超量時保留頭尾
- **跳過雜訊 session**：已處理、沒有真人輸入、headless／SDK 自動化（實測一台機器 20 個 session 有 16 個是記憶壓縮工具）、結晶化本身
- **遮罩 secret**：專案 `.env`／`.env.local` 的實際值，以及 `sk-…`、`Bearer …`、`xc-token`、`*_KEY=` 等寫法。
  實測在真實紀錄上，4 把外洩過的 key 全部遮掉
- **`existing_rules`**：每次全文讀取的比對基準；報告新增「矛盾」一節與每個模式的「狀態」欄
- **暫存放 `.nfd/tmp/`**，跑完刪除；原版試跑時兩台機器都把含明文 key 的濃縮稿留在 `/tmp`
- `/nfd-init` 預設寫 `.git/info/exclude`，不改動被追蹤的 `.gitignore`
- 註明 headless 執行的權限寫法

## 相容性

`condense-sessions.mjs` 只用 Node 內建模組（Claude Code 本來就需要 Node）。已在 macOS 與 Ubuntu 的實際 session 紀錄上測過。

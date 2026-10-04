# kala_plugins

Kala 的 Claude Code plugin marketplace。

## 安裝

在 Claude Code 裡：

```
/plugin marketplace add kalashnikov/kala_plugins
/plugin install feature-ideation@kala
/plugin install claude-nfd@kala
/plugin install ste-html@kala
```

或用 CLI：

```bash
claude plugin marketplace add kalashnikov/kala_plugins
claude plugin install feature-ideation@kala
claude plugin install claude-nfd@kala
claude plugin install ste-html@kala
```

## Plugins

| Plugin | 說明 |
|---|---|
| [feature-ideation](plugins/feature-ideation) | 繁體中文版 feature-ideation，fork 自 [koshian-plugins](https://github.com/alphabet-h/koshian-plugins)（MIT）。解決「點子一直累積，但沒人回頭看」：點子存進專案的 `docs/feature-ideas.md`，依效益・難度・限制打標籤，`discuss` 決定做不做，`check` 用腳本實際計數找出被放著爛掉的項目。詳見 [plugin README](plugins/feature-ideation/README.md)。 |
| [claude-nfd](plugins/claude-nfd) | 繁體中文版 claude-nfd，fork 自 [koshian-plugins](https://github.com/alphabet-h/koshian-plugins)（MIT）。`/crystallize` 從 session 紀錄萃取「怎麼做事」的模式，逐條比對專案既有規則，找出**規則與實際行為的落差**、過時描述與新慣例；只產報告，由人挑選後整合。session 紀錄先濃縮並遮罩 secret，跳過 headless 雜訊。跟原版指令同名，只能啟用其中一個。詳見 [plugin README](plugins/claude-nfd/README.md)。 |
| [ste-html](plugins/ste-html) | 複雜回答輸出成一頁單檔 HTML（面板 + 表格、流程、時序、樹狀、時間軸元件，深淺色、RWD），文字遵守 ASD-STE100 簡化技術英文：短句、主動語態、一詞一義、保留語氣詞。規則與 linter 取自 [asd-ste100-skill](https://github.com/danyuchn/asd-ste100-skill)（MIT），一頁 HTML 的概念取自 [answer-me-with-html](https://github.com/QingYunA/answer-me-with-html)，但沒有用它的程式碼。純 Python 標準函式庫，沒有網路呼叫。詳見 [plugin README](plugins/ste-html/README.md)。 |

## 評估過但沒收錄

koshian-plugins 其他 plugin 的評估（2026-09），供參考：

| Plugin | 結論 | 理由 |
|---|---|---|
| [harness-kit](https://github.com/alphabet-h/koshian-plugins/tree/master/plugins/harness-kit) | 只取 `agents/evaluator.md` | evaluator 規則是「有疑慮就 FAIL」，4 軸各 1–10 分、30/40 及格，會扣 AI 風格設計的分數。`/harness-init` 的 `features.json` + `claude-progress.txt` 適合從零開始的長任務，對已有進度檔與計畫文件的既有專案是重複負擔。Stop hook 只在有 `features.json` 時觸發並檢查 `stop_hook_active`，這個設計值得借用。 |
| [trap-book](https://github.com/alphabet-h/koshian-plugins/tree/master/plugins/trap-book) | 暫不使用 | 實測跑不起來：Stop hook 讀 transcript 用錯欄位（實際是 `type` + `message.role`），自動抽取永遠不觸發；macOS 沒有 `tac` 且開了 `set -e`；意圖比對只認日文與英文；需要 `kb-mcp`。可借用的設計：`[PRIVATE]` 前綴跳過單輪、`.xxx-ignore` 跳過單一專案。 |
| design-kit / design-forge | 跳過 | 用來「製作 design skill」的工具，與既有 design skill 重疊。 |

## 更新 plugin

1. 修改 `plugins/<name>/` 後，**調高 `plugins/<name>/.claude-plugin/plugin.json` 的 `version`**，否則已安裝的機器不會拿到新內容。
2. `claude plugin validate .` 通過後 push。
3. 各機器：`claude plugin marketplace update kala && claude plugin update <name>@kala`，重開 session 生效。

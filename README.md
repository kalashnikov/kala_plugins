# kala_plugins

Kala 的 Claude Code plugin marketplace。

## 安裝

在 Claude Code 裡：

```
/plugin marketplace add kalashnikov/kala_plugins
/plugin install feature-ideation@kala
```

或用 CLI：

```bash
claude plugin marketplace add kalashnikov/kala_plugins
claude plugin install feature-ideation@kala
```

## Plugins

| Plugin | 說明 |
|---|---|
| [feature-ideation](plugins/feature-ideation) | 繁體中文版 feature-ideation，fork 自 [koshian-plugins](https://github.com/alphabet-h/koshian-plugins)（MIT）。解決「點子一直累積，但沒人回頭看」：點子存進專案的 `docs/feature-ideas.md`，依效益・難度・限制打標籤，`discuss` 決定做不做，`check` 用腳本實際計數找出被放著爛掉的項目。詳見 [plugin README](plugins/feature-ideation/README.md)。 |

## 評估過但沒收錄

koshian-plugins 其他 plugin 的評估（2026-09），供參考：

| Plugin | 結論 | 理由 |
|---|---|---|
| [claude-nfd](https://github.com/alphabet-h/koshian-plugins/tree/master/plugins/claude-nfd) | 直接用原版 | `/crystallize` 從 session 紀錄抽出可寫成規則或 skill 的模式（Nurture-First Development，arXiv 2603.10808）。只有 1 次案例的標成「先觀察」，寫進規則前一定等人確認，沒有 hook。缺點：吃 token、要另開 session 跑、介面日文、只讀本機 Claude Code 的 session。已有跨工具記憶系統的話，它的價值在「把經驗升級成 repo 內規則」，不是記憶本身。 |
| [harness-kit](https://github.com/alphabet-h/koshian-plugins/tree/master/plugins/harness-kit) | 只取 `agents/evaluator.md` | evaluator 規則是「有疑慮就 FAIL」，4 軸各 1–10 分、30/40 及格，會扣 AI 風格設計的分數。`/harness-init` 的 `features.json` + `claude-progress.txt` 適合從零開始的長任務，對已有進度檔與計畫文件的既有專案是重複負擔。Stop hook 只在有 `features.json` 時觸發並檢查 `stop_hook_active`，這個設計值得借用。 |
| [trap-book](https://github.com/alphabet-h/koshian-plugins/tree/master/plugins/trap-book) | 暫不使用 | 實測跑不起來：Stop hook 讀 transcript 用錯欄位（實際是 `type` + `message.role`），自動抽取永遠不觸發；macOS 沒有 `tac` 且開了 `set -e`；意圖比對只認日文與英文；需要 `kb-mcp`。可借用的設計：`[PRIVATE]` 前綴跳過單輪、`.xxx-ignore` 跳過單一專案。 |
| design-kit / design-forge | 跳過 | 用來「製作 design skill」的工具，與既有 design skill 重疊。 |

## 更新 plugin

1. 修改 `plugins/<name>/` 後，**調高 `plugins/<name>/.claude-plugin/plugin.json` 的 `version`**，否則已安裝的機器不會拿到新內容。
2. `claude plugin validate .` 通過後 push。
3. 各機器：`claude plugin marketplace update kala && claude plugin update <name>@kala`，重開 session 生效。

# ste-html

把複雜的回答做成**一頁單檔 HTML**，頁面文字遵守 **ASD-STE100 簡化技術英文**的寫作規則。SKILL 本體用英文寫；頁面語言跟著提問走（英文問就出英文頁，中文問就出繁中頁）。

## 來源

| 取自 | 取了什麼 | 怎麼處理 |
|---|---|---|
| [danyuchn/asd-ste100-skill](https://github.com/danyuchn/asd-ste100-skill)（MIT，commit 32511c6） | STE 寫作規則、`ste-lint.py`、`writing-rules.md`、`before-after.md` | linter 和 references 原封不動複製；規則濃縮後寫進 SKILL.md |
| [QingYunA/answer-me-with-html](https://github.com/QingYunA/answer-me-with-html)（MIT，commit 300b530） | 概念：一頁 HTML 回答、面板 + 元件、輸出前先檢查 STE、中文 STE 規則（句長 35/45 字、虛動詞、的字、套話） | **沒有用它任何程式碼**，模板、CSS 和 build 腳本都是重寫的 |

### 為什麼不直接用 answer-me-with-html

審過原始碼（2026-10-04），沒找到惡意行為，但有幾點不適合直接裝：

- `scripts/am.mjs` 是 298 KB 的打包檔（內含 marked、dagre），很難逐行確認和 `src/` 一致。
- 每次 render 會在背景 detached spawn 一個 process，到 `raw.githubusercontent.com` 檢查新版本（可關，但預設開）。
- 影片功能有 `ELEVENLABS_API_KEY` 時會把旁白文字送到 ElevenLabs。
- SKILL.md 與 CLI 訊息是簡體中文。

ste-html 的做法：模型直接寫 HTML 片段（只寫內容，不寫 CSS），`build.py`（Python 標準函式庫，約 200 行）套模板、跑 lint、寫檔、`open`。沒有網路呼叫，沒有 Node 依賴。代價是沒有 SVG 自動排版：流程圖、時序圖改用 CSS 元件，複雜圖才手寫 inline SVG。

## 檔案

```
skills/ste-html/
├── SKILL.md                     何時出頁、流程、STE 規則（英文）
├── assets/template.html         頁面外殼：CSS token、深淺色、RWD、深淺切換鈕
├── references/components.md     元件片段：callout、表格徽章、flow、seq、tree、timeline、kv、meter、svg
├── references/writing-rules.md  STE 規則背景（原檔）
├── references/before-after.md  改寫範例（原檔）
└── scripts/
    ├── build.py                 套模板 + lint + 寫檔 + open
    └── ste-lint.py              英文 STE linter（原檔）
```

## 用法

觸發條件和原版 answer-me-with-html 類似：3 個以上互相關聯的概念、有分支的流程、3 維以上的比較、層級、時間演進，或說「畫個圖」「用 HTML 講」「看不懂」。

流程：模型用 Write 把 body 寫到 `~/.ste-html/drafts/<slug>.html`，再跑

```bash
python3 skills/ste-html/scripts/build.py --in ~/.ste-html/drafts/x.html --title "標題"
```

輸出到 `~/.ste-html/pages/`，自動開瀏覽器（`--no-open` 關掉）。不用 heredoc 把內容 pipe 進 python3，因為 shell_security hook 會擋這種寫法。

也能當單純的 STE 改寫工具：「apply STE100 to this」「disambiguate this」只回改寫後的文字；說「show the diff」才出 before/after 頁。

## Lint 檢查什麼

| 語言 | 硬規則 | 建議（advisory） |
|---|---|---|
| 英文（ste-lint.py） | 分號、軟性片語動詞、名詞化、行銷形容詞、句長 > 25 詞、同義詞輪替 | 被動語態、現在完成式 |
| 中文（build.py） | 全形分號、虛動詞（進行／加以／予以／作出）、一個子句 3 個「的」、套話、句長 > 45 字 | — |

不檢查語氣詞（may、might、could）：把 hedge 刪掉等於改寫了主張。`<code>`、`<pre>`、`<svg>`、`<del>`、`.bad`、`.no-lint` 裡的文字不檢查。

## 跟 answer-me-with-html 並存

兩者觸發條件重疊。用 ste-html 就把原版移除（plugin 安裝的：`claude plugin uninstall answer-me-with-html@answer-me-with-html`；npx skills 安裝的：`npx skills remove answer-me-with-html -g`），不然模型會在兩個之間隨機挑一個。

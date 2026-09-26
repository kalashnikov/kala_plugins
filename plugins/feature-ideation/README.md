# feature-ideation（繁體中文版）

Fork 自 [koshian-plugins/feature-ideation](https://github.com/alphabet-h/koshian-plugins/tree/master/plugins/feature-ideation) v0.1.4（commit 227fdeb），MIT。

與原版差異：
- skill 與 references 翻成繁體中文，vault 區段標題與欄名改用繁中
- `lib/vault-digest.sh` 同時認得繁中與日文標題（日文 vault 仍可用），輸出訊息改繁中
- 修正 macOS 上 `sort | uniq` 把不同 CJK 字元視為相同、導致類別/效益計數錯誤的問題（`LC_COLLATE=C`）
- 修正 macOS bash 3.2 在 `$( )` 內解析 `case` 的 bug：原本 DETAIL DIR 區段會印出原始碼片段，缺檔偵測從未生效

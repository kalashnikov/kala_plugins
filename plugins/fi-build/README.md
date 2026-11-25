# fi-build

```
/plugin install fi-build --marketplace kalashnikov/kala_plugins
```

feature-ideation 的實作階段，兩個手動指令：

```
/feature-ideation discuss FI-NNN   ← 決定做不做（不變）
/fi-build:plan FI-NNN              ← 摸清程式碼 → 決定形狀 → 實測分岔 → 寫 plan → 停
  （使用者說 go，照平常實作）
/fi-build:verify FI-NNN            ← 真實對象驗證、影響範圍、數字檢查 → 證據表
/feature-ideation archive FI-NNN   ← 收尾（不變）
```

- 兩個 skill 都是 `disable-model-invocation`，不會自動觸發，也不會自動進下一步。
- plan 寫到專案的 plan 目錄（依 vault「與既有文件的分工」表），vault 狀態改 `planned`。
- verify 只讀不改；沒過的項目只回報，不自己修。
- 只用 Claude，無多模型、無 PR 流程。

## 單項工具（不綁 FI，可口語呼叫）

這六個沒有 `disable-model-invocation`：可以打指令，也可以直接說「查一下為什麼這樣寫」「教我這塊」。description 都寫明「只在使用者明確要求時使用」，不會自己跳出來。

| 指令 | 用途 | 口語例 |
|---|---|---|
| `/fi-build:why` | 從 commit／PR 紀錄回答為什麼這樣寫，引用原話、推論標推論 | 「這段當初為什麼這樣寫」 |
| `/fi-build:how` | 子系統怎麼運作、資料怎麼流、該放哪一層 | 「帶我看這塊的架構」 |
| `/fi-build:teach` | 跑 how＋why，白話教到懂，圖一張張疊 | 「教我 flyover 怎麼運作」 |
| `/fi-build:blast-radius` | 改動在 diff 外會弄壞什麼，跑腳本證明安全的關鍵事實 | 「這個改動會影響什麼」 |
| `/fi-build:correct` | 反覆被糾正的錯，升級成架構／型別／檢查腳本 | 「這個錯一直重複，讓它不會再發生」 |
| `/fi-build:sharpen` | 把任務改深不改大，重寫 prompt | 「幫我把這個題目磨利」 |

和主流程的重疊：`verify` 第 3 步已含 blast-radius 的核心，`plan` 第 1 步已含 how。FI 流程照用 plan／verify；這六個是平常隨手用的。

## 來源

改寫自 [pstack](https://github.com/cursor/plugins/tree/main/pstack)（poteto／Lauren Tan，MIT）：
how、architect（含 design-red-flags）、prototype playbook、principle-prove-it-works、
blast-radius、principle-explain-the-number、benchmark-checklist；
單項工具改寫自 why、how、teach、blast-radius、correct、sharpen。
拿掉 Cursor 專屬功能、多模型 panel、PR／swarm／live lane，改成繁中並接上 feature-ideation vault。

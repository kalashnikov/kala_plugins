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

## 來源

改寫自 [pstack](https://github.com/cursor/plugins/tree/main/pstack)（poteto／Lauren Tan，MIT）：
how、architect（含 design-red-flags）、prototype playbook、principle-prove-it-works、
blast-radius、principle-explain-the-number、benchmark-checklist。
拿掉 Cursor 專屬功能、多模型 panel、PR／swarm／live lane，改成繁中並接上 feature-ideation vault。

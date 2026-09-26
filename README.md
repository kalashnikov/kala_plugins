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
| [feature-ideation](plugins/feature-ideation) | 繁體中文版 feature-ideation，fork 自 [koshian-plugins](https://github.com/alphabet-h/koshian-plugins)（MIT）。發想功能點子存進 vault，依效益・難度・限制打標籤並可視化優先度。 |

## 更新 plugin

1. 修改 `plugins/<name>/` 後，**調高 `plugins/<name>/.claude-plugin/plugin.json` 的 `version`**，否則已安裝的機器不會拿到新內容。
2. `claude plugin validate .` 通過後 push。
3. 各機器：`claude plugin marketplace update kala && claude plugin update <name>@kala`，重開 session 生效。

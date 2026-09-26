#!/usr/bin/env node
/**
 * 把 Claude Code 的 session 紀錄（~/.claude/projects/<project>/*.jsonl）濃縮成
 * 只剩「真人輸入、assistant 文字、工具呼叫摘要、工具錯誤」的 Markdown，給 /crystallize 分析用。
 *
 * 為什麼需要：原版「每個 JSONL 讀末尾 2000 行」在實務上失效——單檔常常不到 2000 行卻有好幾 MB
 * （附件、檔案快照），直接 Read 會塞爆 context；只讀末尾又會丟掉開頭的需求。
 *
 * 用法（在專案根目錄）：
 *   node condense-sessions.mjs --out .nfd/tmp/sessions [--processed .nfd/tmp/processed.txt]
 *        [--project-dir <dir>] [--max-chars 40000] [--include-headless]
 *
 * 輸出：每個保留的 session 一個 <date>_<id8>.md；stdout 印一張 Markdown 摘要表（含跳過原因）。
 * 只讀不改 session 紀錄。
 */

import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const args = process.argv.slice(2);
const opt = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 && args[i + 1] && !args[i + 1].startsWith("--") ? args[i + 1] : fallback;
};
const flag = (name) => args.includes(`--${name}`);

const configDir = process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), ".claude");
const projectDir =
  opt("project-dir") || path.join(configDir, "projects", process.cwd().replace(/[^A-Za-z0-9]/g, "-"));
const outDir = opt("out", ".nfd/tmp/sessions");
const maxChars = Number(opt("max-chars", "40000"));
const includeHeadless = flag("include-headless");
const processedFile = opt("processed");
const processed = new Set(
  processedFile && fs.existsSync(processedFile)
    ? fs.readFileSync(processedFile, "utf8").split(/\s+/).filter(Boolean)
    : [],
);

const SELF_PATTERN = /crystallize|結晶化/i;

/** 專案 .env／.env.local 裡的實際值（長度 >= 8），出現就整段換掉——比任何樣式比對都可靠 */
const knownSecrets = [".env", ".env.local"]
  .filter((f) => fs.existsSync(f))
  .flatMap((f) => fs.readFileSync(f, "utf8").split("\n"))
  .map((l) => l.match(/^\s*(?:export\s+)?[A-Za-z_][A-Za-z0-9_]*\s*=\s*["']?([^"'#\s]+)/)?.[1])
  .filter((v) => v && v.length >= 8 && !/^https?:\/\//.test(v))
  .sort((a, b) => b.length - a.length);

/** 遮掉 secret。濃縮檔會被 subagent 讀進 context，也可能被寫進報告 */
function redact(s) {
  for (const v of knownSecrets) s = s.split(v).join("***");
  return s
    .replace(/\bsk-[A-Za-z0-9_-]{16,}/g, "sk-***")
    .replace(/\b([A-Za-z_][A-Za-z0-9_]*)=(["']?)(?=[A-Za-z0-9_-]*[0-9])(?=[A-Za-z0-9_-]*[A-Za-z])[A-Za-z0-9_-]{24,}/g, "$1=$2***")
    .replace(/\b(Bearer|Basic)\s+[A-Za-z0-9._~+/=-]{16,}/gi, "$1 ***")
    .replace(/(xc-token|x-api-key|authorization)(["']?\s*[:=]\s*["']?)[^\s"',}]{8,}/gi, "$1$2***")
    .replace(/\b([A-Z][A-Z0-9_]*(?:KEY|TOKEN|SECRET|PASSWORD|PASS))(\s*[=:]\s*["']?)[^\s"'$]{8,}/g, "$1$2***")
    .replace(/(--(?:secret|token|password|api-key))([ =])[^\s"']{8,}/gi, "$1$2***");
}
const clip = (s, n) => {
  const t = redact(s);
  return t.length > n ? `${t.slice(0, n)}…（截斷 ${t.length - n} 字）` : t;
};

/** 從 user 訊息取出真人輸入；系統包裝（system-reminder、local-command 輸出等）回傳 null */
function humanText(content) {
  let text =
    typeof content === "string"
      ? content
      : Array.isArray(content)
        ? content.filter((b) => b.type === "text").map((b) => b.text).join("\n")
        : "";
  if (!text) return null;
  text = text
    .replace(/<system-reminder>[\s\S]*?<\/system-reminder>/g, "")
    .replace(/<local-command-caveat>[\s\S]*?<\/local-command-caveat>/g, "")
    .trim();
  if (!text || /^<(local-command-stdout|bash-stdout|bash-stderr)>/.test(text)) return null;
  if (/^\[Request interrupted/.test(text)) return null;
  const cmd = text.match(/<command-name>([^<]*)<\/command-name>[\s\S]*?(?:<command-args>([\s\S]*?)<\/command-args>)?/);
  if (cmd) return `${cmd[1].trim()} ${(cmd[2] || "").trim()}`.trim();
  const bash = text.match(/^<bash-input>([\s\S]*?)<\/bash-input>/);
  if (bash) return `! ${bash[1].trim()}`;
  return text;
}

function toolSummary(block) {
  const input = block.input || {};
  const detail =
    input.command ?? input.file_path ?? input.pattern ?? input.path ?? input.url ?? input.description ?? input.prompt ?? "";
  return `→ ${block.name}(${clip(String(detail).replace(/\s+/g, " "), 160)})`;
}

function condense(file) {
  const id = path.basename(file, ".jsonl");
  const stat = fs.statSync(file);
  const lines = fs.readFileSync(file, "utf8").split("\n");
  const events = [];
  let entrypoint = "";
  let first = "";
  let last = "";
  let humans = 0;

  for (const line of lines) {
    if (!line.trim()) continue;
    let rec;
    try {
      rec = JSON.parse(line);
    } catch {
      continue;
    }
    if (!entrypoint && rec.entrypoint) entrypoint = rec.entrypoint;
    if (rec.timestamp) {
      if (!first) first = rec.timestamp;
      last = rec.timestamp;
    }
    const content = rec.message?.content;
    if (rec.type === "user" && !rec.isMeta) {
      if (Array.isArray(content)) {
        for (const b of content) {
          if (b.type === "tool_result" && b.is_error) {
            const body = typeof b.content === "string" ? b.content : JSON.stringify(b.content);
            events.push({ kind: "error", text: `✗ ${clip(body.replace(/\s+/g, " "), 300)}` });
          }
        }
      }
      const h = humanText(content);
      if (h) {
        humans += 1;
        events.push({ kind: "human", text: `**USER**：${clip(h, 1500)}` });
      }
    } else if (rec.type === "assistant" && Array.isArray(content)) {
      for (const b of content) {
        if (b.type === "text" && b.text.trim()) events.push({ kind: "text", text: `ASSISTANT：${clip(b.text.trim(), 800)}` });
        else if (b.type === "tool_use") events.push({ kind: "tool", text: toolSummary(b) });
      }
    }
  }

  const firstHuman = events.find((e) => e.kind === "human")?.text || "";
  const base = { id, date: (first || "").slice(0, 10), rawBytes: stat.size, humans };
  if (processed.has(id)) return { ...base, skip: "已處理" };
  if (humans === 0) return { ...base, skip: "沒有真人輸入" };
  if (entrypoint === "sdk-cli" && !includeHeadless) return { ...base, skip: "headless／SDK" };
  if (SELF_PATTERN.test(firstHuman)) return { ...base, skip: "crystallize 本身" };

  // 真人輸入與錯誤一定保留；其餘依頭 25%／尾 75% 的額度保留，中間標示省略
  const mandatory = events.reduce((n, e) => n + (e.kind === "human" || e.kind === "error" ? e.text.length : 0), 0);
  let budget = Math.max(maxChars - mandatory, 0);
  const keep = new Array(events.length).fill(false);
  events.forEach((e, i) => {
    if (e.kind === "human" || e.kind === "error") keep[i] = true;
  });
  let headBudget = Math.floor(budget * 0.25);
  for (let i = 0; i < events.length && headBudget > 0; i++) {
    if (keep[i]) continue;
    keep[i] = true;
    headBudget -= events[i].text.length;
  }
  let tailBudget = budget - Math.floor(budget * 0.25);
  for (let i = events.length - 1; i >= 0 && tailBudget > 0; i--) {
    if (keep[i]) continue;
    keep[i] = true;
    tailBudget -= events[i].text.length;
  }

  const out = [];
  let dropped = 0;
  events.forEach((e, i) => {
    if (keep[i]) {
      if (dropped) out.push(`…（中略 ${dropped} 筆）…`);
      dropped = 0;
      out.push(e.text);
    } else dropped += 1;
  });
  if (dropped) out.push(`…（中略 ${dropped} 筆）…`);

  const body =
    `# session ${id}\n\n` +
    `- 期間：${first} ～ ${last}\n- 入口：${entrypoint || "未知"}\n` +
    `- 原始大小：${(stat.size / 1024).toFixed(0)} KB，真人輸入 ${humans} 則，事件 ${events.length} 筆\n\n` +
    out.join("\n\n") +
    "\n";
  fs.mkdirSync(outDir, { recursive: true });
  const outFile = path.join(outDir, `${base.date || "unknown"}_${id.slice(0, 8)}.md`);
  fs.writeFileSync(outFile, body);
  return { ...base, outFile, chars: body.length };
}

if (!fs.existsSync(projectDir)) {
  console.log(`找不到 session 目錄：${projectDir}`);
  process.exit(0);
}
const files = fs
  .readdirSync(projectDir)
  .filter((f) => f.endsWith(".jsonl"))
  .map((f) => path.join(projectDir, f))
  .sort((a, b) => fs.statSync(a).mtimeMs - fs.statSync(b).mtimeMs);

const rows = files.map(condense);
const kept = rows.filter((r) => !r.skip);
console.log(`來源：${projectDir}`);
console.log(`保留 ${kept.length}／${rows.length} 個 session，輸出到 ${outDir}，合計 ${kept.reduce((n, r) => n + r.chars, 0)} 字\n`);
console.log("| session | 日期 | 原始 KB | 真人輸入 | 結果 |");
console.log("|---|---|---:|---:|---|");
for (const r of rows) {
  const result = r.skip ? `跳過：${r.skip}` : `保留 ${r.chars} 字 → ${path.basename(r.outFile)}`;
  console.log(`| ${r.id.slice(0, 8)} | ${r.date} | ${(r.rawBytes / 1024).toFixed(0)} | ${r.humans} | ${result} |`);
}

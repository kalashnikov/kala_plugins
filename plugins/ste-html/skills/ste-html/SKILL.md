---
name: ste-html
description: >-
  Renders a complex answer as a one-page, single-file HTML explainer whose prose follows
  ASD-STE100 Simplified Technical English (short sentences, active voice, one word one meaning,
  hedges kept). You write only the panel body. A stdlib Python script wraps it in the template,
  lints the prose, writes the file, and opens it. Use proactively when the answer has: 3+
  interrelated concepts; a flow, protocol, or architecture with branches or several actors; a
  comparison across 3+ dimensions; a hierarchy; phases over time; or when the user says "explain
  how it works", "draw a diagram", "explain visually", "I don't get it", "用 HTML 講", "畫個圖",
  "看不懂". Also use when the user asks to apply STE100 / disambiguate / rewrite text so an agent
  cannot misread it. Do not use for short answers (clear in under ~150 words), commands to copy
  and run, pure code changes, or when the user asks for plain text.
---

# STE HTML: answer with one clear HTML page

Two sources, merged:

- **Writing rules** come from ASD-STE100 via [danyuchn/asd-ste100-skill](https://github.com/danyuchn/asd-ste100-skill) (MIT). `scripts/ste-lint.py` is that repo's linter, unchanged.
- **The output idea** (one-page visual answer, panels, components, lint before publish) comes from [QingYunA/answer-me-with-html](https://github.com/QingYunA/answer-me-with-html). None of its code is used here.

You write the HTML **body** only: a lead sentence and panels made from the components in `references/components.md`. `scripts/build.py` adds the page shell, the CSS (light + dark), and the header, then lints and writes the file. Do not write `<html>`, `<head>`, `<style>`, or color values.

Paths below are relative to this skill's base directory (shown when the skill loads). Write them as absolute paths in commands.

## 1. Decide: page or plain text

Make a page when any of these is true:

- The reader must see how 3 or more concepts relate.
- There is a flow, protocol, call chain, or state change, especially with branches or several actors.
- There is a comparison across 3 or more dimensions, a trade-off, or a can / cannot list.
- There is a hierarchy or a sequence of phases.

Otherwise, answer in plain text. If the user asked for plain text, never make a page.

**STE rewrite requests.** When the user gives text and asks to apply STE / disambiguate / simplify it, do not make an explainer page. Rewrite the text under section 3. Output only the rewritten text, plus one `Kept as-is:` line if you kept a longer phrase on purpose. Make a before/after page only if the user asks for the reasoning ("show the diff", "which rules did it break"): one table panel with columns Rule / Original / Simplified, originals wrapped in `<del>`.

## 2. Workflow (one Bash call)

1. Plan 3–8 panels. Each panel answers one sub-question. Put the answer first: the `lead` paragraph or panel A states the conclusion. Later panels give the evidence.
2. Write in the user's language. English question → English page. Chinese question → Traditional Chinese (zh-Hant) page. Keep code, identifiers, and proper nouns as they are.
3. Pick a component for each panel by the shape of the information (table below). Read `references/components.md` the first time in a session.
4. Write the body with the Write tool to `~/.ste-html/drafts/<slug>.html`:

```html
<p class="lead">The core answer in one or two sentences.</p>
<div class="grid cols-3">
  <section class="panel span-2">
    <h2><span class="id">A</span>Panel title</h2>
    <div class="body">…</div>
  </section>
</div>
```

5. Render it:

```bash
python3 "<skill-dir>/scripts/build.py" --in ~/.ste-html/drafts/<slug>.html --title "Title" --subtitle "One line" --meta "source: RFC 9293"
```

Flags: `--lang en|zh-Hant` (auto-detected otherwise), `--out PATH` (default `~/.ste-html/pages/<timestamp>-<slug>.html`), `--no-open` (do not open the browser), `--strict` (refuse to write when hard findings exist), `--lint-only`. Do not pipe the body through a heredoc. Use the draft file.

6. Read the output:
   - `✓ <path>`: the page is written and opened.
   - `STE <rule>: … in: "<text>"`: rewrite that sentence and edit the draft, and render again with the same `--out` path. Do at most 2 retries. Fix every hard finding you can. Advisory findings (passive voice, present perfect) are judgment calls. Keep them when the compound form or the unknown actor carries meaning.
7. In the terminal, reply with 2–3 lines: the core conclusion and the page path. Do not paste the HTML back.

To change one panel of an existing page, edit that `<section>` in the draft, then render again with the same `--out` path. Do not rewrite the whole draft.

### Pick a component

| Information shape | Component |
|---|---|
| Conclusion, warning, risk | `callout ok / info / warn / err` |
| Comparison, can / cannot, trade-offs | `table` with `b ok / b no / b warn` badges |
| Pipeline, architecture, decision path | `flow` (`flow v` for narrow panels) |
| Messages between actors over time | `seq` |
| Directories, modules, taxonomy | `tree` |
| History, phases, versions | `timeline` |
| Spec sheet, metadata | `dl.kv` |
| Value against a limit (real numbers only) | `meter` |
| Anything the above cannot show | inline `svg.fig` using `currentColor` |

Rules: one question per panel. More than 8 panels → split the page or cut. Do not invent data. Mark illustrative numbers as illustrative.

## 3. Writing rules (STE)

The page prose must follow these. The lint checks the mechanical ones. You check the rest.

**Structural rules: apply.**

- Active voice. Name the actor: "The agent deletes the file", not "The file is deleted". Exception: the actor is unknown or does not matter.
- One instruction per sentence. Write steps as imperatives in an ordered list.
- Sentence length: steps ≤ 20 words, descriptions ≤ 25 words. Chinese: steps ≤ 35 characters, descriptions ≤ 45 characters.
- No semicolons (`;` or `；`). Split the sentence.
- No phrasal verbs: "start", not "spin up" or "kick off". "Contact", not "reach out".
- Verbs, not nominalizations: "analyze", not "perform an analysis of". Chinese: "優化", not "進行優化". No 加以, 予以, 作出 + verb.
- Noun clusters: 3 words at most. Chinese: at most two 的 in one clause.
- Keep the subject, verb, and article. Do not drop words to save space.
- One topic per paragraph, 6 sentences at most. Use a list for 3 or more steps or conditions.
- No marketing words: seamless, robust, powerful, cutting-edge, 賦能, 閉環, 無縫, 一站式. Give the measurement or delete the word.

**Lexical rules: direction only.**

- One word, one meaning. Pick one name for one thing and use it on the whole page ("check", never also "verify" / "confirm" for the same action).
- Prefer the short common word: "use", not "utilize". "Start", not "commence". "Before", not "prior to".
- Define each domain term once, the first time it appears.
- This skill does not have ASD's official ~900-word dictionary. Never claim STE compliance. "STE-flavored" is the correct name for the result.

**Content rules: never break.**

- **Keep modality.** "May have failed" stays "may have failed". Do not turn a hedge into a fact to shorten a sentence. Confidence is content.
- **Add no facts.** A rewrite that supplies a cause, a frequency, or a mechanism the source did not state is not a rewrite.
- **Keep precision.** If a shorter sentence would drop a safety condition, a scope limit, or a number, keep the longer sentence.
- Present perfect: use the simple past ("the job completed"). Keep "has completed" only when current relevance is the point.
- Cutting words is not the goal. Removing ambiguity is the goal. Stop when the sentence is clear, not when it is shortest.

Show a bad example on purpose with `<del>` or `class="bad"`. The lint skips both. Mark quoted text that must stay verbatim with `class="no-lint"`.

Full rule background: `references/writing-rules.md`. Worked before/after examples: `references/before-after.md`.

## 4. Privacy and side effects

- `build.py` and `ste-lint.py` use the Python standard library only. They make no network calls.
- The only side effects: the draft under `~/.ste-html/drafts/`, one page under `~/.ste-html/pages/` (or `--out`), and `open <file>` on macOS unless `--no-open`.
- Pages accumulate. When the user asks to clean up, list `~/.ste-html/pages/` and `drafts/`, state the count and size, and delete only after the user agrees.

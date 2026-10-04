# Components

Copy these snippets into the body you pipe to `build.py`. Every class below is styled in `assets/template.html`. Do not add `<style>` blocks or inline colors. The template tokens handle light and dark mode.

## Page skeleton

```html
<p class="lead">One or two sentences. The core answer.</p>
<div class="grid cols-3">
  <section class="panel span-2">
    <h2><span class="id">A</span>Panel title<span class="note">optional right note</span></h2>
    <div class="body">…component or prose…</div>
  </section>
  <section class="panel">
    <h2><span class="id">B</span>Next panel</h2>
    <div class="body">…</div>
  </section>
</div>
```

- Grid: `cols-1` to `cols-4`. Default to `cols-3` for an overview sheet, `cols-1` for a linear step-by-step read.
- Panel width: `span-2`, `span-3`, `span-all`. Give the densest panel more width.
- Panel IDs: A, B, C… in reading order.

## Callout — conclusion, warning, error

```html
<div class="callout ok"><strong>Recommendation</strong>Use option B. It removes the lock.</div>
```

Kinds: `info`, `ok`, `warn`, `err`.

## Table with status badges — comparison, can / cannot list

```html
<table>
  <tr><th>Option</th><th>Offline</th><th>Cost</th></tr>
  <tr><td>A</td><td><span class="b ok">✓ yes</span></td><td>Free</td></tr>
  <tr><td>B</td><td><span class="b no">✗ no</span></td><td><span class="b warn">! metered</span></td></tr>
</table>
```

Badges: `b ok`, `b no`, `b warn`, `b info`.

## Flow — pipeline, architecture, decision path

```html
<div class="flow">
  <div class="node">Client</div>
  <div class="arrow">HTTPS</div>
  <div class="node hl">Gateway<small>auth + rate limit</small></div>
  <div class="arrow"></div>
  <div class="node dec">Cache hit?</div>
</div>
```

- `flow v` stacks it vertically. Use vertical in narrow panels.
- `node hl` marks the key node. `node dec` (dashed) marks a decision.
- For branches, fan-out, or loops, use one flow per branch, or an inline SVG (see below).

## Sequence — messages between actors over time

```html
<div class="seq" style="--n:2">
  <div class="actor">Client</div><div class="actor">Server</div>
  <div class="msg r" style="grid-column:1/3">SYN</div>
  <div class="msg l" style="grid-column:1/3">SYN-ACK</div>
  <div class="msg r dash" style="grid-column:1/3">ACK</div>
  <div class="phase">connection open</div>
</div>
```

- Set `--n` to the actor count. Each `msg` spans the columns between its two actors (`grid-column: from / to+1`).
- `r` points right, `l` points left, `dash` means a reply or an async message.

## Tree — hierarchy, directories, taxonomy

```html
<ul class="tree">
  <li><code>src/</code>
    <ul>
      <li><code>api/</code> <span class="d">HTTP handlers</span></li>
      <li><code>core/</code> <span class="d">domain logic, no I/O</span></li>
    </ul>
  </li>
</ul>
```

## Timeline — history, phases

```html
<ol class="timeline">
  <li><span class="t">2019</span><br><strong>v1</strong> — single server.</li>
  <li class="hl"><span class="t">2023</span><br><strong>v2</strong> — sharded. Current.</li>
</ol>
```

## Key–value — metadata, spec sheet

```html
<dl class="kv"><dt>Protocol</dt><dd>TCP</dd><dt>Port</dt><dd><code>443</code></dd></dl>
```

## Meter — a value against a limit

```html
<div class="meter">Sentence length 18 / 20 words<div class="bar"><i style="width:90%"></i></div></div>
<div class="meter over">Payload 6 / 5 MB<div class="bar"><i style="width:100%"></i></div></div>
```

Use real numbers only. If the numbers are illustrative, say so in the panel.

## Inline SVG — only when no component fits

```html
<svg class="fig" viewBox="0 0 320 120" role="img" aria-label="Retry loop">
  <rect x="10" y="40" width="90" height="36" rx="5" fill="none" stroke="currentColor"/>
  <text x="55" y="63" text-anchor="middle" fill="currentColor" font-size="13">Request</text>
</svg>
```

- Use `currentColor` or `var(--accent)` / `var(--err)` for strokes and fills, so dark mode works.
- Keep all text inside the viewBox. Check that labels do not overlap.

## Showing a bad example on purpose

Wrap the text in `<del>` or `<span class="bad">`. The STE lint skips both. Use `class="no-lint"` on any element whose prose you quote verbatim and must not change.

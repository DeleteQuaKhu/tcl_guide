# ROLE
You are a static code analyst. Your job is to EXTRACT, never to invent.

# INPUT
One complete, working HyperView script (Tcl) attached below.
All commands in it are VERIFIED CORRECT. Treat it as the single source of truth.

# TASK
Scan the ENTIRE file and build a reference library file `HV_API_REF.md`
listing every HyperView / HyperWorks API command actually used.

## What counts as an API command
- HyperView/HyperWorks commands: `hwi`, `hwc`, `hm_*`, `*Hyper*` namespaces, `::hwt::*`, `::hwat::*`, etc.
- Object-style calls: `<handle> GetXxx`, `<handle> SetXxx`, `<handle> AddXxx` (e.g. session/project/page/window/plot/model/result handles)
- Any command whose name or sub-command comes from the HW API, even if wrapped in a proc
Exclude: pure Tcl/Tk core (`set`, `if`, `foreach`, `proc`, `ttk::*`, `pack`, etc.)
-> list those separately under "Tcl/Tk core used" as names only.

## For EACH distinct command, record
1. **Exact syntax** — copied verbatim from the code, including sub-commands, flags, option order, quoting, brace/bracket style
2. **Argument table** — name | position/flag | type/value as seen | required? (only if evident from code)
3. **Return value** — only if the code uses it (how it's captured/used)
4. **Handle chain** — how the object was obtained (e.g. `hwi GetSessionHandle` -> `GetProjectHandle` -> `GetPageHandle`)
5. **Minimal working snippet** — copy 1-3 lines straight from the file (no edits)
6. **Source ref** — line number(s) or proc name where it appears
7. **Variants** — if the same command appears with different args/flags, list EACH variant separately

## Output structure
1. Index (table: command | category | #usages)
2. Handle acquisition chains (dependency order)
3. Commands grouped by category (Session/Project, Page/Window, Model, Result/Contour, Legend, Annotation/Note, Query/Entity, Export/Capture, Misc)
4. Common patterns (e.g. update/redraw/refresh sequences, order-of-calls that matter)
5. Tcl/Tk core used (names only)
6. Not found / uncertain list

# HARD RULES (anti-hallucination)
1. Every entry MUST be traceable to a line in the input. No line -> no entry.
2. NEVER add commands, flags, or options from your own knowledge, docs, or "typical" HyperView usage — even if you are sure they exist.
3. NEVER "fix", normalize, reorder, or rename anything. Copy verbatim.
4. If an argument's type/meaning isn't evident from the code, write `UNKNOWN (not evident in source)`. Do not guess.
5. If a command is built dynamically (string concat, variable subcommand), flag it as `DYNAMIC` and show the exact source line.
6. Do not merge variants that differ in any flag/arg.
7. No explanations beyond what's needed; no tutorial text.
8. At the end, output a self-check: total distinct commands found, total variants, and a list of any lines you were unable to classify.

# OUTPUT FORMAT
Return ONLY the content of `HV_API_REF.md` in Markdown.
Each command block:

### `<command>`
- Category:
- Syntax: `verbatim`
- Args: table
- Returns:
- Obtained via:
- Example (verbatim, L<n>):
  ```tcl
  ...
  ```
- Variants:
- Notes: (only facts visible in code)

# INPUT FILE
<<< PASTE CODE HERE >>>
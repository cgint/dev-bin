When creating Markdown documents, consider whether a diagram would improve human understanding; use D2 when helpful.

**Mandatory for Processes:**
For any Markdown doc/change that describes a **process/flow/sequence of events/state machine**, ALWAYS add a D2 diagram and render it to SVG.

- Only skip the diagram if the user explicitly says "no diagram"; otherwise treat diagrams as required for process docs.

**Workflow:**

1. **Create** (`*.d2`):
   - Use as little formatting as possible and only for structuring the diagram.
   - The convert script will use light theme and nice layout defaults.
   - Use bold and normal text for headings and content respectively.
   - Use background colors on any box if it helps for the structure.
   - Reduce the amount of text to an understandable minimum.
   - Keep it simple — prefer multiple smaller diagrams over one large diagram.
   - Use `direction: down` as the default unless you have strong reasons to use `direction: right`.
2. **Convert** (`d2to.sh file.d2` → `file.svg`):
   - Helper-Script `d2to.sh` is a global system tool available in $PATH
   - Running `d2to.sh file.d2` will create `file.svg` with layout defaults.
3. **Embed**:
   - Add a `## Diagram` section near the top with `![...](./file.svg)`.

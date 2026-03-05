---
name: web-browser-use
description: Automate web browser tasks using agent-browser CLI and browsershot.sh for simple screenshots
---

# Web Browser Automation

This skill provides CLI-based browser automation capabilities using agent-browser, a system-wide browser automation tool.

## Tool

**agent-browser** - Browser automation CLI with viewport control, navigation, and screenshots.

**browsershot.sh** - Helper script for one-command screenshots (URL -> PNG).

## Quick Usage (browsershot.sh)

Use `browsershot.sh` for a simple screenshot of a URL. Default viewport is 1024x768; two numbers at the start = resolution; `--full` captures the entire page.

```bash
# Capture screenshot (saves to generated filename based on URL)
browsershot.sh https://example.com

# Capture screenshot to specific file
browsershot.sh https://example.com output.png

# Custom resolution (e.g. 1440x900 desktop, 1920x1080 HD)
browsershot.sh 1440 900 https://example.com example_com.png

# Full page capture (entire scrollable page, not just viewport)
browsershot.sh --full https://example.com full-page.png
```

## Advanced Usage (agent-browser)

Use agent-browser in **single steps** - one command per invocation. Chaining multiple commands (especially click, type) often leads to session hanging.

```bash
# Basic usage - run each command separately
agent-browser set viewport <width> <height>
agent-browser open <url>
agent-browser screenshot <filename>
```

**For screenshots**: Prefer `browsershot.sh` over agent-browser chaining. It handles viewport, navigation, and capture in one reliable call.

### Get Help

```bash
agent-browser -h
browsershot.sh -h
```

## Examples

```bash
# Screenshot a URL (preferred)
browsershot.sh 1440 900 https://example.com example_com_1440x900.png

# Single-step agent-browser workflow
agent-browser set viewport 1024 768 && \
agent-browser open https://example.com && \
agent-browser snapshot -i
# Then start the interaction with single step commands
agent-browser click @e2
agent-browser fill @e3 "test@example.com"
agent-browser click @e4
agent-browser screenshot after-fill.png
```

## When to Use This Skill

Use `agent-browser` when you need to:
- Automate web testing and validation
- Take screenshots of websites or UI elements
- Verify visual designs or renderings
- Test user flows end-to-end
- Create documentation with visual screenshots
- Perform repetitive web tasks

## How It Works

1. **Screenshots**: Use `browsershot.sh <url> [output.png]` for quick captures
2. **agent-browser**: Use single-step commands - set viewport, navigate, interact (click, type), capture
3. **One command at a time**: Avoid chaining; run each command separately to prevent session hangs

---  

## Best Practices

- **Inspect first, screenshot second**: For debugging/assertions, prefer DOM/accessibility inspection first, then capture screenshots for human-facing evidence.
- **Use deterministic checks**: Prefer `agent-browser get count <selector>` and `agent-browser is visible <selector>` over visual guessing.
- **Use snapshots for discoverability**: `agent-browser snapshot -i -c` helps find actionable refs/selectors quickly.
- **Screenshots**: Use `browsershot.sh` for URL-to-PNG capture; it's reliable and avoids chaining issues.
- **Single steps**: Run one agent-browser command at a time; chaining click/type often hangs the session.
- **Viewport management**: Set viewport before interactions (e.g., `1024 768` or `2048 1080`).
- **Screenshot naming**: Use descriptive names like `homepage.png`, `checkout-flow.png`, `login-success.png`.
- **Documentation**: Use screenshots as evidence for user acceptance testing or documentation.
- **Browser context**: Ensure the target website is accessible and doesn't have strict bot detection.

## Inspect-First Verification Pattern

Use this sequence when you need confidence beyond visual checks:

```bash
# 1) Navigate and set viewport
agent-browser --session verify-ui set viewport 1920 1080
agent-browser --session verify-ui open http://localhost:4001/acp-controller

# 2) Deterministic assertions
agent-browser --session verify-ui get count "[data-testid='target-element']"
agent-browser --session verify-ui is visible "[data-testid='target-element']"

# 3) Discover interactive refs (if needed)
agent-browser --session verify-ui snapshot -i -c -d 5

# 4) Human-readable evidence (only if needed)
browsershot.sh 1920 1080 http://localhost:4001/acp-controller evidence-1920x1080.png
```

## Example from Practice (ACP related OpenSpec chips)

Problem: verify whether related OpenSpec chips are rendered in the session header/sidebar.

What worked best:

```bash
agent-browser --session inspect-related open http://localhost:4001/acp-controller/session/<task-id>
agent-browser --session inspect-related get count "[data-testid='session-log-related-openspec-changes']"
agent-browser --session inspect-related get count "[data-testid='session-summary-related-openspec-changes-<task-id>']"
agent-browser --session inspect-related get count "[data-testid^='session-summary-related-openspec-change-<task-id>-']"
```

Interpretation:
- If counts are `0`, the UI is not rendering these elements (deterministic evidence).
- Then cross-check persisted source-of-truth (`metadata.json`) before taking visual screenshots.
- Capture screenshots only if you need to communicate spacing, alignment, overflow, or other layout behavior.

## Verification Manifest (Priority Order)

When checking UI information, use this order by default:

1. **Structured checks first** (DOM/state assertions)
   - `get count`, `is visible`, `get text`, targeted selectors.
2. **Accessibility/interaction map second**
   - `snapshot -i -c` to discover refs and confirm interactive structure.
3. **Storage/state cross-check third**
   - Validate backing data files/APIs (e.g., metadata, JSON responses).
4. **Screenshots last (when necessary)**
   - Use screenshots for visual/layout-only questions: alignment, spacing, clipping, overflow, typography, and presentation evidence.

Rule of thumb: if a question can be answered by deterministic inspect/state methods, do that first and avoid screenshot-first debugging.

## Tips

- **Screenshot paths**: Screenshots are saved in the current working directory unless specified otherwise.
- **Viewport options**: Common sizes are 1024x768 (laptop), 1440x900 (desktop), 1920x1080 (HD).
- **Multiple shots**: Take screenshots at different stages to document the full user journey.
- **Session isolation**: Use `--session <name>` so repeated inspect commands stay in one browser context.
- **Selector robustness**: Prefer stable selectors (`data-testid`, role/label locators) over brittle CSS paths.

---  

## Workflow Example

```bash
# Screenshot pages with browsershot.sh
browsershot.sh https://your-app.com login-page.png

# For interactive flows, run agent-browser one step at a time
agent-browser set viewport 1440 900
agent-browser open https://your-app.com
agent-browser screenshot login-page.png
# Proceed with click, type, etc. - one command per step
```

---  

## Integration with Pi

This skill pairs well with:
- **Design reviews**: Take screenshots to document UI at specific stages
- **Documentation**: Use visual evidence in READMEs or technical docs
- **Automated testing**: Build test scripts with verification steps
- **Team presentations**: Capture UI states for demos and presentations

**Important**: When you make a screenshot to understand what is on the UI then also load it, look at it and ask yourself if what is on there is what you expect it to be! 
---
name: diagrams
description: Create/convert diagrams (d2to.sh for D2->SVG, plantuml.sh for PlantUML->SVG/PNG)
---

# Diagram Creation & Conversion

This skill helps you create, edit, and convert diagrams using two popular diagramming tools.

## Available Tools

### 1. D2 Diagrams
**Tool**: `d2to.sh`

Converts D2 diagram files to SVG format.

**Examples of D2-Daigram definition**:
```d2
direction: down
title: ACP Controller Selector & Backend Abstraction {near: top-center}

Controller {
    user: User {
        shape: person
    }
    ui: "UI /acp-controller"
}

Backend {
    facade: "Genie.ACP"
    registry: "Config Registry"
    supervisor: "ConnectionSupervisor"
    pubsub: PubSub

}
Controller.user -> Controller.ui: "1. Selects Backend\n2. Clicks Connect"
Controller.ui -> Backend.facade: start_connection(id)
Backend.pubsub -> Controller.ui: "Stream Updates"

Backend.facade -> Backend.registry: Lookup(id)
Backend.registry -> Backend.facade: "{Module, Opts}"
Backend.facade -> Backend.supervisor: "start_child(Module, Opts)"
Backend.facade -> Backend.pubsub: "Broadcast Events"
```

```d2
title: Pi RPC Protocol Flow | {near: top-center}

Message Generation {
  Pi -> Client: "message_start"
  loop Streaming {
    Pi -> Client: "message_update (deltas)"
  }
  Pi -> Client: "message_end"
}
```

**Noteworthy D2 diagram attributes**:
- Shapes: rectangle, square, page, parallelogram, document, cylinder, queue, package, step, callout, stored_data, person, diamond, oval, circle, hexagon, cloud


**Usage of tool**: `d2to.sh <input.d2> [output.svg] [d2_options...]`
   - `d2_options` are options to pass to d2 (if omitted, recommended defaults are used)
   - The rendering layout defaults to `-l dagre` which is good at hierarchical 'top-to-bottom' flow (more human appealing usually - preferred).
   - Use `-l elk` to select the Eclipse Layout Kernel layout engine in case you really need orthogonal (right-angle) routing.

**Examples**:
```bash
d2to.sh meeting.d2
# Generates meeting.svg in the same directory

d2to.sh meeting.d2 meeting_down.svg
# Generates meeting_down.svg
```

### 2. PlantUML Diagrams
**Tool**: `plantuml.sh`

Converts PlantUML files to SVG or PNG format using Docker.

**Usage**: `plantuml.sh <input.puml>`

**Example**:
```bash
plantuml.sh diagram.puml
# Generates diagram.svg in the same directory
```

---

## When to Use This Skill

Use this skill when you need to:
- Create a D2 diagram and render it to SVG
- Convert an existing D2 file to an image for documentation
- Convert a PlantUML file to SVG or PNG
- Document processes, flows, or system architectures visually

---

## How to Get Started

1. Decide which diagram format you need (D2 or PlantUML)
   - Unless told otherwise use PlantUML only for UML diagrams, else use D2 for all other diagrams.
2. Create your diagram file with your preferred tool
3. Use the corresponding conversion script:
   - For D2: `d2to.sh <your-file.d2>`
   - For PlantUML: `plantuml.sh <your-file.puml>`
4. Check the generated SVG/PNG file in your project directory

---

## Best Practices

- **D2**: Use it for simple flowcharts, state machines, and process diagrams. Lightweight and easy to read.
  - Use `direction: down` as the default unless you have strong reasons to use `direction: right`.
- **PlantUML**: Use it for complex diagrams, UML class diagrams, and when you need advanced diagram types.
- **Keep it simple**: Both tools support inline comments (e.g., `# comment`) - use them to document your diagrams.

---

## Tips

- Check `d2to.sh -h` or `plantuml.sh -h` for detailed options
- Docker is required for `plantuml.sh`
- Generated files have `.svg` or `.png` extension for easy inclusion in documentation
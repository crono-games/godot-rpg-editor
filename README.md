# Godot RPG Editor

**Godot RPG Editor** is a framework designed to build **event-driven gameplay systems** using a **node-based visual scripting interface**.

Instead of writing gameplay events entirely in code, the editor allows you to construct them through a **graph of nodes**, where each node represents a specific action or logic block. This makes it easier to design complex event workflows such as:

- Dialogue systems
- Gameplay triggers
- Scripted sequences
- Cutscenes
- Interactive gameplay logic

The goal is to provide a **more visual and data-driven workflow** for designing gameplay interactions while keeping the system modular and extensible.

---

## Project Status

The project is still evolving. While the **core systems are already functional**, several aspects of the framework are still being improved, including architecture, usability, and tooling.

> The foundation is stable, but the editor should still be considered **work in progress**.

---

## Current Features

- **Node-based visual scripting** for event workflows  
- **Modular node architecture** for extending functionality  
- **Data-driven event execution system**  
- **Support for both 2D and 3D environments**  
  - ⚠️ 3D support is still in an early stage

---

## Work in Progress

Some areas still require improvement and may change in the future:

- General **code refactoring and architectural cleanup**
- **Editor UX improvements**
- Additional **built-in nodes and utilities**
- Improvements to the **3D workflow**
- Better **event debugging tools**

---

# Usage

## Creating Events

To create a new event:

1. **Right click** in the **2D viewport**
2. A context popup will appear
3. Select one of the following:

- `EventInstance`
- `PlayerInstance`

*image*

---

## Editing Events

Once an **EventInstance** has been placed in the scene:

1. Select the instance
2. Press **Edit Event**
3. Or open the **Event Editor** directly

*image*

---

## Event Graph

Inside the Event Editor you will see a **node graph** that defines the flow of the event.

Each node represents part of the logic controlling the event state.

You can configure:

- Event **triggers**
- **Properties** for the current event state
- The **flow of execution**

To add a new node:

1. Drag from the default connection slot
2. A popup menu will appear
3. Select the desired node type

*image*

---

## Philosophy

The editor focuses on three core ideas:

- **Visual event design**
- **Modular systems**
- **Data-driven gameplay logic**

The long-term goal is to create a workflow where **designers can build complex event logic without writing large amounts of code**, while developers can still extend the system with custom nodes.

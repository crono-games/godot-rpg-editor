# Godot RPG Editor

> ⚠️ This project is still under active development and parts of the internal architecture may change.

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

Several areas are still evolving and will likely change:

- **General code refactoring and architectural cleanup**
- **Improving internal system structure**
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

<img width="300" height="160" alt="image" src="https://github.com/user-attachments/assets/2a282ce8-3adc-4811-899e-44824efbb224" />


---

## Editing Events

Once an **EventInstance** has been placed in the scene:

1. Select the instance
2. Press **Edit Event**
3. Or open the **Event Editor** directly

<img width="212" height="34" alt="image" src="https://github.com/user-attachments/assets/4c795324-36fb-4047-8c92-678bfe1ec612" />

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

<img width="368" height="190" alt="image" src="https://github.com/user-attachments/assets/6045ee06-8cc0-4366-86d1-314ae1e87cc6" />

---

## Philosophy

The editor focuses on three core ideas:

- **Visual event design**
- **Modular systems**
- **Data-driven gameplay logic**

The long-term goal is to create a workflow where **designers can build complex event logic without writing large amounts of code**, while developers can still extend the system with custom nodes.

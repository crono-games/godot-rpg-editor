Godot  RPG Editor is a framework for building event-based gameplay logic using a graph nodes / visual scripting interface. The idea is to make it easier to design event workflows (dialogue, triggers, scripted sequences, gameplay logic, etc.) without writing everything directly in code.
Instead of scripting events manually, you build them through nodes that represent different actions and logic blocks.

The project is still evolving and there are quite a few things I want to improve (architecture cleanup,  some UX improvements, new nodes, etc.), but the core is already working and most of the fundamental pieces are there.

**Current Features**

Node-based visual scripting for event workflows

Modular node system

Data-driven event execution

Support for both 2D and 3D environments (3D it's in early stage yet)

Things that still need work

Some parts are still rough and will likely change:

General code refactoring and cleanup

Improvements to the editor UX

The 3D version of the framework still needs a lot of adjustments

More built-in nodes and utilities

Better debugging tools for events

So I wouldn't call it a finished tool yet, but the base is there and I'm trying improving it actively.

**How to add new Events:**

Right click in 2D viewport and this popup will appear. You can add an EventInstance or PlayerInstance.

<img width="195" height="129" alt="image" src="https://github.com/user-attachments/assets/b12aff9c-3156-4e12-b92f-ab95cdf08404" />

EventInstances can be edited by selecting them and press Edit Event Button or directly pressing Event Editor button.

<img width="241" height="38" alt="image" src="https://github.com/user-attachments/assets/dfeadbf8-5b6a-4c2f-9a26-06e0b66f02e9" />

<img width="104" height="51" alt="image" src="https://github.com/user-attachments/assets/d1232f33-fb6c-4288-a000-4fb128d692ea" />

You'll see a Node that defines the flow, you can select trigger and properties of the current state of the event.
To add a new Node you drag from the default slot and a Popup will appear, allowing to select a new Node.

<img width="648" height="296" alt="image" src="https://github.com/user-attachments/assets/8f85105f-6b45-4fe1-968a-82b22cc1d4ae" />


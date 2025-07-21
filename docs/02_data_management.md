# 2. Centralized State Management

A cornerstone of the FERS-UI architecture is its centralized state management, embodied by a global singleton. This
design pattern ensures that all simulation configuration data has a "Single Source of Truth."

## The Single Source of Truth

At the heart of the UI lies a dedicated global object responsible for holding and managing all simulation element data (
platforms, pulses, antennas, global parameters, etc.). This means:

* **One canonical data set:** There is only one authoritative copy of the simulation data. This eliminates ambiguity and
  simplifies data consistency checks.
* **Global accessibility:** Any part of the application can access the current state of the simulation data by querying
  this central object.

## Reactive Data Flow

Communication and data flow within FERS-UI are primarily reactive, minimizing direct coupling between UI components.

### How Data Updates Happen:

1. **User Interaction:** When a user interacts with a UI control (e.g., typing a new value in a property editor,
   selecting a different option from a dropdown, adding a new element), the UI component does *not* directly update
   another UI component.
2. **Notify Central Store:** Instead, the UI component notifies the central data object about the requested change. It
   calls a method on the central object, passing the identifier of the element to be changed, the property key, and the
   new value.
3. **Data Processing:** The central data object processes this request. This might involve:
    * Directly updating the property.
    * Performing validation or transformation on the data.
    * Triggering more complex logic, such as re-structuring data for platform type changes.
4. **Emit Signals:** After successfully updating its internal data, the central data object emits a specific signal (
   e.g., `element_updated`, `element_added`, `element_removed`). These signals carry information about what changed (
   e.g., the element's ID and its new data).

### How UI Reacts to Data Changes:

1. **Listen to Signals:** Other UI components (e.g., the scene hierarchy, property inspector, or the 3D world view) do
   not actively poll the central data store for changes. Instead, they register to listen for specific signals emitted
   by the central data object.
2. **Update Responsively:** When a signal is received, the listening UI component updates its own display to reflect the
   new state of the data. For example, if a platform's name is changed in the property inspector, the central data
   object emits an `element_updated` signal, and the scene hierarchy immediately updates the platform's name in its tree
   view.

## Benefits of this Approach

* **Decoupling:** UI components are largely independent. They don't need to know about each other, only about the
  central data store. This significantly reduces inter-component dependencies.
* **Consistency:** Because all data flows through a single point, it's easier to maintain data integrity and consistency
  across the entire application.
* **Maintainability:** Changes to one UI component or data structure are less likely to break other parts of the
  application, as long as the contract with the central data store (method calls and signals) remains stable.
* **Testability:** The central data store can be tested in isolation, independent of the UI, ensuring the core
  simulation logic is sound.
* **Reactivity:** The UI automatically reflects data changes, providing a fluid and intuitive user experience.
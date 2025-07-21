# 5. XML Data Interchange

FERS-UI acts as a graphical front-end for the Flexible Extensible Radar Simulator (FERS), a C++-based simulation engine.
To facilitate seamless communication with this core engine, XML is used as the primary data interchange format.

## The Role of XML

XML (Extensible Markup Language) is chosen for its human-readability, hierarchical structure, and long-standing
compatibility with the FERS core. It serves as the bridge between the UI's internal data model and the input/output
requirements of the C++ simulator.

## Exporting to FERS XML

The UI provides functionality to convert the currently configured simulation scenario into a valid FERS XML input file:

1. **Data Traversal:** The exporter systematically traverses the UI's internal data model, collecting all necessary
   properties and relationships for each simulation element (platforms, pulses, antennas, timing sources, and global
   parameters).
2. **XML Structure Generation:** It constructs the XML document according to the FERS schema, creating appropriate XML
   tags, attributes, and nested structures. This involves mapping UI-specific properties (e.g., `platform_type_actual`,
   `monostatic_pulse_id_ref`) to their corresponding FERS XML elements and attributes (
   `<platform type="monostatic" antenna="AntennaName">`).
3. **Reference Resolution:** For linked elements (e.g., an antenna assigned to a platform), the exporter resolves
   internal UI IDs to the names expected by the FERS engine.
4. **Serialization:** The generated XML document is then serialized into a string and can be saved to a file, ready for
   consumption by the FERS core simulator.

This ensures that any scenario built visually within FERS-UI can be directly executed by the high-performance C++
simulation engine.

## Importing from FERS XML

The UI also supports loading existing FERS XML configuration files, allowing users to visualize and modify scenarios
created outside the UI or from previous runs:

1. **File Parsing:** The XML content is parsed, and the XML document structure is traversed.
2. **Internal Model Reconstruction:** For each XML element encountered (e.g., `<platform>`, `<pulse>`, `<timing>`), the
   importer:
    * Determines its type.
    * Generates a new, unique internal ID for the element.
    * Extracts its attributes and child element values.
    * Maps these XML values back to the corresponding properties in the UI's internal data model. This includes handling
      complex nested structures and reference IDs.
    * Creates a new data entry in the central data store.
3. **UI Synchronization:** As each element is added to the central data store, it emits signals (e.g., `element_added`),
   which the UI components (Scene Hierarchy, 3D View) listen for, causing the visual representation of the imported
   scenario to appear.
4. **State Reset:** Before importing, the existing dynamic elements in the UI's data model are cleared to ensure a clean
   slate for the new scenario.

## Challenges and Considerations

* **Schema Mapping:** Maintaining a precise mapping between the UI's flexible internal data structure and the strict
  FERS XML schema is crucial. This involves handling potential naming differences, data type conversions, and
  hierarchical representation.
* **Error Handling:** Robust error handling during XML parsing and data mapping is essential to inform the user of
  invalid or malformed input files.
* **Backward/Forward Compatibility:** As the FERS core or UI evolves, ensuring compatibility with older/newer XML
  versions might require versioning strategies or transformation layers.

# Individual Processing

Functions in this folder load Homer `.nirs` recordings, validate acquisition structure, detect conditions, call Homer2 numerical functions, extract complete epochs, apply baseline correction, and assemble participant block and condition responses.

`preprocess_recording` is the orchestration function. Loading, acquisition validation, and condition detection are separate calls so their requirements and reports remain available to the caller. Function headers define the expected structures, dimensions, units, and error identifiers.

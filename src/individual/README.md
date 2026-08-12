# Individual-Level Processing

Maintained functions in this folder implement `.nirs` loading and translation, raw-recording validation, condition detection, isolated Homer2 numerical boundaries, complete-epoch extraction, baseline correction, and participant preprocessing orchestration.

The public orchestration boundary is `preprocess_recording`. Loading, validation, and condition detection are deliberately separate. Function headers document exact structures, dimensions, units, and error contracts.

# Historical Provenance

## Interpretation

Historical MATLAB and Homer scripts informed the scientific context and helped recover operation signatures, parameters, and downstream requirements. They are evidence of workflow development, not maintained production code. Filenames containing `Final`, `Finalized`, version numbers, or similar labels do not by themselves establish scientific authority.

The maintained implementation is a standardized canonical workflow informed by the final dissertation methods, historical source review, and downstream derivative requirements. It should not be interpreted as a claim that one script, or one byte-identical chain of scripts, generated every dissertation result.

## Known methodological divergence

The maintained workflow applies exactly one `0.01–0.10 Hz` bandpass to wavelet-corrected optical density before modified Beer–Lambert conversion. The written dissertation methods described modified Beer–Lambert conversion before filtering. Historical code also contained narrow-band, sequential-filter, baseline, and outlier variants. These alternatives are not silently merged into the canonical path.

The configured DPF `[6 6]` was repeatedly observed in historical scripts but was not numerically specified in the dissertation. It remains configurable and requires verification against authoritative acquisition records.

## Block-level preservation

Historical downstream analyses did not all summarize the task over the same time window. Repo 1 therefore preserves each complete baseline-corrected HbO/HbR block across the full configured epoch and records its original event ordinal. Task-window selection, block summaries, ICC, SPSS export, and other inferential decisions remain responsibilities of Repo 2.

## Public-repository boundary

The current Git history contains tracked legacy analysis directories with machine-specific paths, derived CSV tables, MATLAB autosave files, and code that may encode private participant workflow details. These folders are not canonical dependencies. Before a public push, they should be removed from the public branch/history or moved to a separately governed private provenance archive after an explicit review.

Participant recordings, participant MAT outputs, SPSS datasets/results, spreadsheets, and identifiable lists must remain private. Maintained tests use synthetic data and temporary stubs only.

# Canonical Methods

## Scope

This repository implements standardized preprocessing and descriptive group aggregation for continuous-wave fNIRS recordings. It produces participant-level HbO/HbR block and condition derivatives and group condition means. Inferential statistics, ICC reliability, anatomy, and publication figures are outside this repository.

The implementation is informed by the final dissertation methods, historical MATLAB/Homer workflows, and downstream analysis requirements. It intentionally selects one explicit canonical pipeline rather than silently combining historical variants.

## Individual preprocessing

1. Load MAT-format Homer-style `.nirs` raw intensity while preserving measurement order and the native Homer2 `SD` structure in a separate adapter context.
2. Validate recording structure and caller-supplied acquisition expectations.
3. Detect required conditions by exact normalized name; do not infer condition position.
4. Convert raw intensity to optical density with Homer2 `hmrIntensity2OD`.
5. Apply Homer2 wavelet motion correction with IQR `1` and explicit `turnon = 1`.
6. Apply exactly one `0.01–0.10 Hz` Homer2 bandpass to motion-corrected optical density.
7. Convert filtered optical density to HbO/HbR with Homer2 modified Beer–Lambert conversion.
8. Extract index-aligned epochs from `−20` through `+30 s`, inclusive when endpoints lie on the sampling grid.
9. Exclude incomplete boundary epochs without padding and report their original onsets.
10. Average complete epochs by condition without baseline subtraction inside the epoching function.
11. Baseline-correct condition averages and every retained individual block using the mean from `−20` through `0 s`.

The DPF is configuration-supplied. `[6 6]` is retained as a historically observed configuration value, but it requires verification against authoritative acquisition records and is not presented as a numerically confirmed dissertation parameter.

## Participant derivatives

Condition HRFs contain baseline-corrected HbO/HbR matrices with dimensions `time × channel`.

Block HRFs contain baseline-corrected HbO/HbR arrays with dimensions `time × channel × retained_block`. Only complete epochs are retained. `block_indices` records original within-condition event ordinals and is not renumbered after a boundary exclusion. `channel_pairs` preserves the MBLL output order.

Full block time series are retained because downstream analyses use different task windows. Repo 1 does not choose or calculate a downstream task-period summary.

## Group processing

Compatible participant condition HRFs are stacked as `time × channel × participant`. Compatibility requires exact time grids and identical channel-pair order; conditions are matched by exact name and emitted in the first participant's order.

For each condition, chromophore, time, and channel:

```matlab
initial_mean = mean(values, 3);
initial_sd   = std(values, 0, 3);
outlier_mask = abs(values - initial_mean) > threshold_sd * initial_sd;
```

The canonical threshold is configuration-supplied as `2`. The SD is MATLAB sample SD (`N−1`), every candidate contributes to the initial statistics, the comparison is strict `>`, and detection occurs once. HbO and HbR are processed independently. The final mean and sample SD are recalculated from retained values; pointwise included/excluded counts are returned. No imputation, interpolation, participant-wide exclusion, SEM, or inferential statistic is performed.

## Scientific boundaries

Homer2 supplies the numerical intensity-to-OD, wavelet, filtering, and MBLL algorithms. Repository wrappers validate inputs, metadata, forwarding, dimensions, and finite outputs but do not reimplement or independently establish Homer2 numerical correctness.

No participant data, channel rejection, participant QC, task summary, ICC, SPSS analysis, anatomical labeling, or publication figure generation occurs in the maintained pipeline.

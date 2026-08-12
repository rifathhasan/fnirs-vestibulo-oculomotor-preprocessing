# Pipeline Overview

## Component boundaries

```text
load_fnirs_recording
  -> standardized recording + separate Homer2 adapter context

validate_raw_recording
  -> structural/acquisition report

detect_conditions
  -> exact-name condition definitions + trial-count report

homer2_preprocessing_operators
  -> isolated external numerical operators

preprocess_recording
  -> condition_hrfs + block_hrfs + epoch_report + preprocessing metadata

aggregate_participant_hrfs
  -> group condition_hrfs + outlier reports + aggregation metadata
```

Loading, acquisition validation, and condition detection remain outside `preprocess_recording`; this separation prevents the orchestrator from inferring file format, acquisition requirements, or condition mappings.

## Individual sequence

```text
raw intensity
-> optical density
-> wavelet motion correction (IQR = 1)
-> exactly one 0.01–0.10 Hz bandpass on motion-corrected OD
-> modified Beer–Lambert conversion
-> continuous HbO/HbR
-> complete epoch extraction (−20 to +30 s)
-> condition average (no baseline subtraction in Stage C)
-> baseline correction (−20 to 0 s)
-> participant condition HRFs
```

The same complete epochs also follow a parallel derivative path:

```text
complete unaveraged HbO/HbR epochs
-> baseline correction of each block (−20 to 0 s)
-> participant block HRFs
```

`block_indices` preserves original event ordinals after boundary exclusions. The arithmetic mean of baseline-corrected blocks agrees with the baseline-corrected condition average within floating-point tolerance because the baseline and averaging operations are linear.

## Group sequence

```text
compatible participant condition HRFs
-> time × channel × participant stack
-> initial pointwise mean and sample SD (N−1)
-> strict > threshold exclusion mask, one pass
-> no imputation
-> final pointwise mean, sample SD, and effective N
```

Outlier detection is independent across condition, chromophore, time, and channel. A participant excluded at one point remains eligible everywhere else.

## Configuration

Scientific parameters are stored in `config/canonical_preprocessing_config.m`. Acquisition expectations are intentionally caller-supplied to `validate_raw_recording`; they are not inferred or silently replaced by nominal study values.

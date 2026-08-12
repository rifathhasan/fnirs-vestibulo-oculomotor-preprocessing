# Pipeline Overview

## Software data flow

```text
load_fnirs_recording
  -> recording
  -> adapter_context

validate_raw_recording(recording, requirements)
  -> validation

detect_conditions(recording.stimuli, required_conditions, expected_trials)
  -> conditions
  -> condition_report

homer2_preprocessing_operators(adapter_context.homer2_sd)
  -> operators

preprocess_recording(recording, validation, conditions, config.individual, operators)
  -> condition_hrfs
  -> block_hrfs
  -> epoch_report
  -> preprocessing

aggregate_participant_hrfs(participant_results, config.group)
  -> group condition_hrfs
  -> outlier_report
  -> aggregation
```

Loading, acquisition validation, and condition detection occur before the numerical preprocessing call. This keeps file translation, acquisition requirements, and condition definitions explicit at the calling boundary.

## Individual recording flow

```text
raw optical intensity
-> optical density
-> wavelet motion correction
-> 0.01 to 0.10 Hz band pass filtering
-> modified Beer Lambert conversion
-> continuous HbO and HbR
-> complete epoch extraction
```

Complete epochs produce two participant outputs:

```text
complete epochs
-> baseline correction of each block
-> block_hrfs

complete epochs
-> condition average
-> baseline correction of the average
-> condition_hrfs
```

Both paths use the same time vector, channel order, and baseline interval. `block_indices` links each retained block to its original condition event ordinal. `epoch_report` records boundary exclusions and trial counts.

## Group flow

```text
compatible participant condition_hrfs
-> time x channel x participant arrays
-> initial pointwise mean and sample standard deviation
-> one strict threshold comparison
-> exclusion mask
-> final mean, sample standard deviation, and pointwise counts
```

HbO and HbR are processed independently. The group output preserves the first participant's condition order and channel order. No value is imputed.

## Configuration boundary

`config/canonical_preprocessing_config.m` stores individual and group processing parameters. Acquisition expectations remain caller supplied because they depend on the recording protocol. Local paths belong in an ignored `config/local_paths.m` file created from `config/local_paths.example.m`.

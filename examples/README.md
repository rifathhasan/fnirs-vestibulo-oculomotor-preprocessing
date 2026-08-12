# Usage Guide

This guide shows the maintained function sequence. It does not include recording data or acquisition specific values.

## Paths and configuration

```matlab
addpath('config');
addpath(fullfile('src', 'individual'));
addpath(fullfile('src', 'group'));

config = canonical_preprocessing_config();
```

Place machine specific paths in an ignored `config/local_paths.m` file if a local runner needs them.

## One recording

```matlab
[recording, adapter_context] = load_fnirs_recording(raw_file);
validation = validate_raw_recording(recording, requirements);
[conditions, condition_report] = detect_conditions( ...
    recording.stimuli, required_conditions, expected_trials);

operators = homer2_preprocessing_operators(adapter_context.homer2_sd);
result = preprocess_recording( ...
    recording, validation, conditions, config.individual, operators);
```

`requirements` must contain the expected sampling rate, sampling rate tolerance, sampling interval tolerance fraction, channel count, and wavelength count. `required_conditions` is a list of exact condition names. `expected_trials` is a nonnegative integer used for the condition count report.

Review `validation` and `condition_report` before using `result`. The result contains baseline corrected block responses, condition responses, epoch records, and the processing parameters used.

## Participant aggregation

```matlab
group_result = aggregate_participant_hrfs(participant_results, config.group);
```

`participant_results` is a structure vector with at least two elements. Each element must contain compatible `condition_hrfs` from `preprocess_recording`. Participant labels may be stored by calling code, but the aggregation functions do not use or return them.

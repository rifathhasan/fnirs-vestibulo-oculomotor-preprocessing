# API Walkthrough

This folder documents maintained interfaces without bundling participant recordings or pretending that acquisition-specific requirements can be inferred.

## Individual recording

The complete call chain is:

```matlab
config = canonical_preprocessing_config();
[recording, adapter_context] = load_fnirs_recording(raw_file);
validation = validate_raw_recording(recording, requirements);
[conditions, condition_report] = detect_conditions( ...
    recording.stimuli, {'EC', 'HS', 'HVOR', 'VVOR'}, expected_trials);
operators = homer2_preprocessing_operators(adapter_context.homer2_sd);
result = preprocess_recording( ...
    recording, validation, conditions, config.individual, operators);
```

The caller supplies `raw_file`, acquisition `requirements`, and `expected_trials`. Real preprocessing also requires the compatible Homer2 functions on the MATLAB path. Review acquisition and condition reports before using the derivatives.

The result contains:

- `condition_hrfs`: baseline-corrected condition averages (`time × channel`);
- `block_hrfs`: baseline-corrected complete blocks (`time × channel × retained_block`);
- `epoch_report`: detected/included/excluded block accounting;
- `preprocessing`: numerical parameters used.

`block_indices` retains original event ordinals. No task-period mean is calculated.

## Group aggregation

```matlab
group_result = aggregate_participant_hrfs(participant_results, config.group);
```

`participant_results` must contain at least two compatible structures with `condition_hrfs`. Participant identifiers are optional caller metadata and are not used or returned by the scientific aggregation function.

See the root [README](../README.md) and [canonical methods](../docs/methods.md) for requirements and scientific decisions.

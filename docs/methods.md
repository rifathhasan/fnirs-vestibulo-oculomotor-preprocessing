# Processing Methods

## Input representation

`load_fnirs_recording` accepts Homer `.nirs` files stored in MATLAB format. The loader returns a standardized recording structure containing raw optical intensity, acquisition time, wavelengths, measurement definitions, stimulus information, and the source format. The native Homer2 `SD` structure is returned separately in `adapter_context.homer2_sd` for numerical functions that require probe metadata.

The maintained loader preserves intensity orientation, measurement order, wavelength order, stimulus onset values, and native probe metadata. SNIRF input is not implemented.

## Acquisition validation

`validate_raw_recording` checks the standardized recording before preprocessing. It requires positive finite raw intensity with dimensions `time x measurement`, a strictly increasing time vector, valid wavelengths, valid source detector wavelength definitions, and consistent stimulus metadata.

Sampling rate, sampling interval consistency, channel count, and wavelength count are evaluated against requirements supplied by the caller. The report records measured values and any acquisition quality control failures. It does not modify the recording.

## Condition detection

`detect_conditions` matches required conditions by exact name after trimming whitespace and converting text to uppercase. It does not infer a condition from stimulus position. Onsets remain in their recorded order, and expected trial count is reported separately from detected trial count.

## Optical processing

The default individual processing configuration applies these operations in order:

1. `hmrIntensity2OD` converts raw optical intensity to optical density.
2. `hmrMotionCorrectWavelet` corrects optical density with IQR equal to `1` and `turnon` equal to `1`.
3. `hmrBandpassFilt` applies one `0.01 to 0.10 Hz` band pass filter to motion corrected optical density.
4. `hmrOD2Conc` applies modified Beer Lambert conversion and returns HbO and HbR concentration changes.

The Homer2 wrapper functions pass measurement arrays without reordering columns. They require finite real outputs with the expected dimensions. The differential pathlength factor is supplied through configuration and defaults to `[6 6]`.

## Epochs and participant responses

`epoch_and_average_conditions` uses sampled condition onsets and a supplied sampling interval. The default epoch extends from minus 20 to plus 30 seconds. Both endpoints are included when they lie on the sampling grid.

An epoch is retained only when every requested sample is present. Boundary epochs are excluded without padding, interpolation, or shortening. The epoch report records detected, retained, and excluded counts together with excluded onset values.

Complete HbO and HbR blocks are stored as `time x channel x retained block`. `block_indices` preserves each block's original event ordinal. Complete blocks are also averaged by condition using the arithmetic mean.

`baseline_correct_hrf` subtracts the channel mean over the default interval from minus 20 to 0 seconds. The function is applied separately to every retained HbO block, every retained HbR block, and each HbO and HbR condition average. Participant block responses and condition responses therefore use the same baseline convention.

## Group aggregation

`aggregate_participant_hrfs` accepts at least two participant results. Condition names are matched exactly, while output condition order follows the first participant. Time vectors, response dimensions, and channel pair order must agree across participants.

For each condition, chromophore, time point, and channel, participant responses are stacked as `time x channel x participant`. `pointwise_group_average` computes:

```matlab
initial_mean = mean(values, 3);
initial_sd   = std(values, 0, 3);
outlier_mask = abs(values - initial_mean) > threshold_sd * initial_sd;
```

The default `threshold_sd` is `2`. The standard deviation uses `N minus 1` normalization. Each participant contributes to the initial mean and standard deviation. The mask is calculated once. Excluded values are not imputed, and exclusion at one point does not remove a participant from another point.

The final group mean and sample standard deviation are calculated from retained values. The report includes the exclusion mask and pointwise retained and excluded counts for HbO and HbR.

## Assumptions

1. Input intensity values are positive and finite.
2. Stimulus onsets correspond exactly to samples in the recording time vector.
3. Epoch boundaries correspond to integer sampling offsets.
4. Homer2 probe metadata describe a complete and unambiguous wavelength layout.
5. Participant responses supplied for group aggregation use identical time samples and channel order.
6. Processing parameters are reviewed for the acquisition protocol before use.

function config = canonical_preprocessing_config()
%CANONICAL_PREPROCESSING_CONFIG Scientific settings for the canonical workflow.
%   CONFIG = CANONICAL_PREPROCESSING_CONFIG() returns a scalar structure of
%   fixed individual- and group-level analysis parameters. Time values are in
%   seconds, frequencies are in hertz, and DPF is a 1-by-2 dimensionless
%   vector. This function stores configuration only; it performs no signal
%   processing.
%
%   Assumptions:
%   - Input begins as raw light intensity.
%   - The bandpass filter is applied exactly once, after wavelet correction
%     and before modified Beer-Lambert conversion.
%   - HbO and HbR are obtained from the modified Beer-Lambert conversion.
%   - Group outlier exclusion is pointwise and does not use imputation.

config.individual.input_representation = 'raw_intensity';
config.individual.motion_correction.method = 'wavelet';
config.individual.motion_correction.iqr = 1;
config.individual.filter.type = 'bandpass';
config.individual.filter.passband_hz = [0.01 0.10];
config.individual.filter.application_count = 1;
config.individual.filter.input_representation = ...
    'motion_corrected_optical_density';
config.individual.concentration_conversion.method = ...
    'modified_beer_lambert';
config.individual.concentration_conversion.dpf = [6 6]; % Requires historical verification.
config.individual.chromophores = {'HbO', 'HbR'};
config.individual.block_average_window_s = [-20 30];
config.individual.baseline_window_s = [-20 0];

config.group.input_level = 'participant_condition_hrf';
config.group.initial_statistics = {'pointwise_mean', 'pointwise_sd'};

% Pointwise group outlier rule:
% abs(value - group_mean) > 2 * group_sd
% Applied across participants independently at each time point and channel.
% Excluded values are not imputed.
config.group.outlier_threshold_sd = 2;
config.group.outlier_rule = 'exclude_values_strictly_greater_than_threshold';
config.group.imputation = 'none';
config.group.recalculate_statistics_after_exclusion = true;
end

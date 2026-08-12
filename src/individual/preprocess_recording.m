function result = preprocess_recording( ...
        recording, validation, conditions, individual_config, operators)
%PREPROCESS_RECORDING Run the canonical individual-recording pipeline.
%   RESULT = PREPROCESS_RECORDING(RECORDING, VALIDATION, CONDITIONS,
%   INDIVIDUAL_CONFIG, OPERATORS) orchestrates already-loaded and validated
%   raw fNIRS intensity through injected numerical operators, repository-
%   native condition epoch averaging, and condition-average baseline
%   correction.
%
%   Inputs:
%     RECORDING         - Standardized scalar recording structure. This
%                         function consumes raw intensity (time by
%                         measurement) and acquisition time in seconds.
%     VALIDATION        - Successful validate_raw_recording report. Its
%                         measured rate and median interval define the
%                         validated acquisition timing used downstream.
%     CONDITIONS        - Nonempty scalar structure of definitions already
%                         produced by detect_conditions.
%     INDIVIDUAL_CONFIG - Canonical individual preprocessing configuration.
%                         Frequencies are in hertz, windows are in seconds,
%                         and DPF is supplied explicitly by the caller.
%     OPERATORS         - Scalar structure containing the four injected
%                         external numerical operation handles.
%
%   Output:
%     RESULT.condition_hrfs - Column struct array of final baseline-
%                              corrected HbO/HbR participant HRFs.
%     RESULT.block_hrfs     - Parallel column struct array of complete,
%                              baseline-corrected individual HbO/HbR blocks.
%                              Arrays are time by channel by retained block;
%                              block_indices records original trial ordinals.
%     RESULT.epoch_report   - Stage C trial accounting, unchanged.
%     RESULT.preprocessing  - Numerical parameters actually used.
%
%   The fixed order is intensity to optical density, wavelet correction,
%   one OD-domain bandpass, MBLL, condition epoch averaging, then baseline
%   correction of each condition average. This function does not load
%   files, inspect native probe metadata, detect conditions, implement
%   numerical Homer algorithms, or perform group processing. The supplied
%   DPF is forwarded without asserting that its value was reported in the
%   dissertation; its historical verification status remains configuration
%   provenance.

if nargin ~= 5
    error('preprocess_recording:InvalidInputCount', ...
        'preprocess_recording requires exactly five inputs.');
end

[intensity, recording_time] = validate_recording(recording);
[qc_passed, validation_pairs] = validate_validation( ...
    validation, recording, recording_time, size(intensity));
validate_conditions_top_level(conditions);
parameters = validate_config(individual_config);
validate_operators(operators);

if ~qc_passed
    error('preprocess_recording:AcquisitionQcFailed', ...
        'Validated acquisition expectations were not met.');
end

od = operators.intensity_to_od(recording.intensity);
corrected_od = operators.wavelet_correct_od( ...
    od, parameters.wavelet_iqr);
filtered_od = operators.bandpass_od( ...
    corrected_od, validation.measured_sampling_rate_hz, ...
    parameters.bandpass_hz(1), parameters.bandpass_hz(2));
concentration = operators.od_to_concentration( ...
    filtered_od, parameters.dpf);

validate_channel_set(concentration, validation_pairs);

[condition_averages, epoch_report, complete_epochs] = ...
    epoch_and_average_conditions( ...
        concentration, recording.time, conditions, ...
        parameters.block_average_window_s, ...
        validation.median_sampling_interval_s);

for condition_index = 1:numel(epoch_report)
    if epoch_report(condition_index).included_trial_count == 0
        error('preprocess_recording:NoIncludedTrials', ...
            'Condition "%s" has no complete included trials.', ...
            epoch_report(condition_index).name);
    end
end

condition_hrfs = condition_averages;
block_hrfs = complete_epochs;
for condition_index = 1:numel(condition_hrfs)
    condition_hrfs(condition_index).HbO = baseline_correct_hrf( ...
        condition_averages(condition_index).HbO, ...
        condition_averages(condition_index).time, ...
        parameters.baseline_window_s);
    condition_hrfs(condition_index).HbR = baseline_correct_hrf( ...
        condition_averages(condition_index).HbR, ...
        condition_averages(condition_index).time, ...
        parameters.baseline_window_s);

    for block_index = 1:numel(complete_epochs(condition_index).block_indices)
        block_hrfs(condition_index).HbO(:, :, block_index) = ...
            baseline_correct_hrf( ...
                complete_epochs(condition_index).HbO(:, :, block_index), ...
                complete_epochs(condition_index).time, ...
                parameters.baseline_window_s);
        block_hrfs(condition_index).HbR(:, :, block_index) = ...
            baseline_correct_hrf( ...
                complete_epochs(condition_index).HbR(:, :, block_index), ...
                complete_epochs(condition_index).time, ...
                parameters.baseline_window_s);
    end
end

preprocessing = struct( ...
    'wavelet_iqr', parameters.wavelet_iqr, ...
    'bandpass_hz', parameters.bandpass_hz, ...
    'dpf', parameters.dpf, ...
    'measured_sampling_rate_hz', validation.measured_sampling_rate_hz, ...
    'median_sampling_interval_s', ...
        validation.median_sampling_interval_s, ...
    'block_average_window_s', parameters.block_average_window_s, ...
    'baseline_window_s', parameters.baseline_window_s);

result = struct('condition_hrfs', condition_hrfs, ...
    'block_hrfs', block_hrfs, ...
    'epoch_report', epoch_report, 'preprocessing', preprocessing);
end

function [intensity, time_column] = validate_recording(recording)
required_fields = {'data_representation', 'intensity', 'time'};
if ~isstruct(recording) || ~isscalar(recording) || ...
        ~all(isfield(recording, required_fields)) || ...
        ~is_raw_intensity_text(recording.data_representation)
    invalid_recording();
end

intensity = recording.intensity;
if ~isnumeric(intensity) || ~isreal(intensity) || isempty(intensity) || ...
        ~ismatrix(intensity) || any(~isfinite(intensity(:))) || ...
        any(intensity(:) <= 0)
    invalid_recording();
end

time = recording.time;
if ~isnumeric(time) || ~isreal(time) || isempty(time) || ...
        ~isvector(time) || any(~isfinite(time(:)))
    invalid_recording();
end
time_column = time(:);
if numel(time_column) < 2 || numel(time_column) ~= size(intensity, 1) || ...
        any(diff(time_column) <= 0)
    invalid_recording();
end
end

function [qc_passed, channel_pairs] = validate_validation( ...
        validation, recording, recording_time, intensity_size)
required_fields = {'is_structurally_valid', 'data_representation', ...
    'time_sample_count', 'measurement_count', ...
    'median_sampling_interval_s', 'measured_sampling_rate_hz', ...
    'sampling_rate_within_tolerance', ...
    'sampling_intervals_within_tolerance', 'channel_count', ...
    'channel_count_matches_expected', 'channel_pairs', ...
    'wavelength_count_matches_expected', 'qc_failures', ...
    'all_acquisition_expectations_met'};
if ~isstruct(validation) || ~isscalar(validation) || ...
        ~all(isfield(validation, required_fields))
    invalid_validation();
end

logical_fields = {'is_structurally_valid', ...
    'sampling_rate_within_tolerance', ...
    'sampling_intervals_within_tolerance', ...
    'channel_count_matches_expected', ...
    'wavelength_count_matches_expected', ...
    'all_acquisition_expectations_met'};
for field_index = 1:numel(logical_fields)
    if ~is_logical_compatible(validation.(logical_fields{field_index}))
        invalid_validation();
    end
end

if ~is_raw_intensity_text(validation.data_representation) || ...
        ~same_canonical_representation(recording.data_representation, ...
        validation.data_representation) || ...
        ~is_nonnegative_integer(validation.time_sample_count) || ...
        ~is_nonnegative_integer(validation.measurement_count) || ...
        ~is_positive_finite_scalar(validation.median_sampling_interval_s) || ...
        ~is_positive_finite_scalar(validation.measured_sampling_rate_hz) || ...
        ~is_nonnegative_integer(validation.channel_count)
    invalid_validation();
end

if numel(recording_time) ~= validation.time_sample_count || ...
        intensity_size(1) ~= validation.time_sample_count || ...
        intensity_size(2) ~= validation.measurement_count
    invalid_validation();
end

recording_median_interval_s = median(diff(recording_time));
if ~approximately_equal_8_ulps(recording_median_interval_s, ...
        validation.median_sampling_interval_s) || ...
        ~approximately_equal_8_ulps( ...
        validation.measured_sampling_rate_hz, ...
        1 / validation.median_sampling_interval_s)
    invalid_validation();
end

channel_pairs = validation.channel_pairs;
if ~is_valid_unique_channel_pairs(channel_pairs) || ...
        size(channel_pairs, 1) ~= validation.channel_count
    invalid_validation();
end

failure_fields = {'check', 'measured_value', 'expected_value', 'tolerance'};
if ~isstruct(validation.qc_failures) || ...
        ~isequal(sort(fieldnames(validation.qc_failures)), ...
        sort(failure_fields(:)))
    invalid_validation();
end

component_success = ...
    logical(validation.sampling_rate_within_tolerance) && ...
    logical(validation.sampling_intervals_within_tolerance) && ...
    logical(validation.channel_count_matches_expected);
if logical(validation.all_acquisition_expectations_met) ~= ...
        component_success || isempty(validation.qc_failures) ~= ...
        component_success || ...
        ~logical(validation.is_structurally_valid) || ...
        ~logical(validation.wavelength_count_matches_expected)
    invalid_validation();
end

qc_passed = component_success;
end

function validate_conditions_top_level(conditions)
if ~isstruct(conditions) || ~isscalar(conditions) || ...
        isempty(fieldnames(conditions))
    error('preprocess_recording:InvalidConditions', ...
        'conditions must be a nonempty scalar structure.');
end
condition_fields = fieldnames(conditions);
for condition_index = 1:numel(condition_fields)
    definition = conditions.(condition_fields{condition_index});
    if ~isstruct(definition) || ~isscalar(definition)
        error('preprocess_recording:InvalidConditions', ...
            'Each supplied condition definition must be a scalar structure.');
    end
end
end

function parameters = validate_config(config)
required_fields = {'input_representation', 'motion_correction', 'filter', ...
    'concentration_conversion', 'chromophores', ...
    'block_average_window_s', 'baseline_window_s'};
if ~isstruct(config) || ~isscalar(config) || ...
        ~all(isfield(config, required_fields)) || ...
        ~is_raw_intensity_text(config.input_representation)
    invalid_config();
end

if ~isstruct(config.motion_correction) || ...
        ~isscalar(config.motion_correction) || ...
        ~all(isfield(config.motion_correction, {'method', 'iqr'})) || ...
        ~text_equals(config.motion_correction.method, 'wavelet') || ...
        ~is_nonnegative_finite_scalar(config.motion_correction.iqr)
    invalid_config();
end

if ~isstruct(config.filter) || ~isscalar(config.filter) || ...
        ~all(isfield(config.filter, {'type', 'passband_hz', ...
        'application_count', 'input_representation'})) || ...
        ~text_equals(config.filter.type, 'bandpass') || ...
        ~text_equals(config.filter.input_representation, ...
        'motion_corrected_optical_density') || ...
        ~is_numeric_value(config.filter.application_count, 1)
    invalid_config();
end
passband_hz = config.filter.passband_hz;
if ~isnumeric(passband_hz) || ~isreal(passband_hz) || ...
        ~isvector(passband_hz) || numel(passband_hz) ~= 2 || ...
        any(~isfinite(passband_hz(:))) || any(passband_hz(:) <= 0)
    invalid_config();
end
passband_hz = passband_hz(:).';
if passband_hz(1) >= passband_hz(2)
    invalid_config();
end

if ~isstruct(config.concentration_conversion) || ...
        ~isscalar(config.concentration_conversion) || ...
        ~all(isfield(config.concentration_conversion, {'method', 'dpf'})) || ...
        ~text_equals(config.concentration_conversion.method, ...
        'modified_beer_lambert')
    invalid_config();
end
dpf = config.concentration_conversion.dpf;
if ~isnumeric(dpf) || ~isreal(dpf) || isempty(dpf) || ...
        ~isrow(dpf) || any(~isfinite(dpf)) || any(dpf <= 0)
    invalid_config();
end

if ~iscell(config.chromophores) || ...
        ~isequal(config.chromophores, {'HbO', 'HbR'})
    invalid_config();
end

block_window = validate_window(config.block_average_window_s, true);
baseline_window = validate_window(config.baseline_window_s, false);
if baseline_window(1) < block_window(1) || ...
        baseline_window(2) > block_window(2)
    invalid_config();
end

parameters = struct('wavelet_iqr', config.motion_correction.iqr, ...
    'bandpass_hz', passband_hz, 'dpf', dpf, ...
    'block_average_window_s', block_window, ...
    'baseline_window_s', baseline_window);
end

function window = validate_window(value, must_span_zero)
if ~isnumeric(value) || ~isreal(value) || ~isvector(value) || ...
        numel(value) ~= 2 || any(~isfinite(value(:)))
    invalid_config();
end
window = value(:).';
if window(1) >= window(2) || ...
        (must_span_zero && (window(1) > 0 || window(2) < 0))
    invalid_config();
end
end

function validate_operators(operators)
required_fields = {'intensity_to_od', 'wavelet_correct_od', ...
    'bandpass_od', 'od_to_concentration'};
if ~isstruct(operators) || ~isscalar(operators) || ...
        ~all(isfield(operators, required_fields))
    invalid_operators();
end
for operator_index = 1:numel(required_fields)
    if ~isa(operators.(required_fields{operator_index}), 'function_handle')
        invalid_operators();
    end
end
end

function validate_channel_set(concentration, validation_pairs)
if ~isstruct(concentration) || ~isscalar(concentration) || ...
        ~isfield(concentration, 'channel_pairs')
    invalid_validation();
end
concentration_pairs = concentration.channel_pairs;
if ~is_valid_unique_channel_pairs(concentration_pairs) || ...
        size(concentration_pairs, 1) ~= size(validation_pairs, 1)
    invalid_validation();
end

[is_present, validation_index_for_result] = ...
    ismember(concentration_pairs, validation_pairs, 'rows');
if ~all(is_present) || ...
        numel(unique(validation_index_for_result)) ~= ...
        size(concentration_pairs, 1)
    invalid_validation();
end
end

function tf = is_valid_unique_channel_pairs(value)
tf = isnumeric(value) && isreal(value) && ~isempty(value) && ...
    ismatrix(value) && size(value, 2) == 2 && ...
    all(isfinite(value(:)));
if tf
    tf = size(unique(value, 'rows'), 1) == size(value, 1);
end
end

function tf = approximately_equal_8_ulps(actual, expected)
scale = max(abs([actual expected]));
tolerance = 8 * eps(scale);
tf = abs(actual - expected) <= tolerance;
end

function tf = is_raw_intensity_text(value)
tf = text_equals(value, 'raw_intensity');
end

function tf = same_canonical_representation(first, second)
tf = is_raw_intensity_text(first) && is_raw_intensity_text(second);
end

function tf = text_equals(value, expected)
text = scalar_text(value);
tf = ~isempty(text) && strcmpi(strtrim(text), expected);
end

function text = scalar_text(value)
text = '';
if ischar(value) && isvector(value) && ~isempty(value)
    text = value(:).';
elseif isstring(value) && isscalar(value) && ~ismissing(value) && ...
        strlength(value) > 0
    text = char(value);
end
end

function tf = is_logical_compatible(value)
tf = (islogical(value) && isscalar(value)) || ...
    (isnumeric(value) && isreal(value) && isscalar(value) && ...
    isfinite(value) && (value == 0 || value == 1));
end

function tf = is_nonnegative_integer(value)
tf = isnumeric(value) && isreal(value) && isscalar(value) && ...
    isfinite(value) && value >= 0 && fix(value) == value;
end

function tf = is_positive_finite_scalar(value)
tf = isnumeric(value) && isreal(value) && isscalar(value) && ...
    isfinite(value) && value > 0;
end

function tf = is_nonnegative_finite_scalar(value)
tf = isnumeric(value) && isreal(value) && isscalar(value) && ...
    isfinite(value) && value >= 0;
end

function tf = is_numeric_value(value, expected)
tf = isnumeric(value) && isreal(value) && isscalar(value) && ...
    isfinite(value) && value == expected;
end

function invalid_recording()
error('preprocess_recording:InvalidRecording', ...
    'recording is inconsistent with the standardized raw recording contract.');
end

function invalid_validation()
error('preprocess_recording:InvalidValidation', ...
    'validation is malformed or inconsistent with the supplied recording.');
end

function invalid_config()
error('preprocess_recording:InvalidConfig', ...
    'individual_config is malformed or contradicts the canonical pipeline.');
end

function invalid_operators()
error('preprocess_recording:InvalidOperators', ...
    'operators must provide the four required function handles.');
end

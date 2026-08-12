function [condition_averages, epoch_report, complete_epochs] = ...
        epoch_and_average_conditions( ...
        concentration, time, conditions, epoch_window, sampling_interval_s)
%EPOCH_AND_AVERAGE_CONDITIONS Extract and average complete condition epochs.
%   [CONDITION_AVERAGES, EPOCH_REPORT, COMPLETE_EPOCHS] =
%   EPOCH_AND_AVERAGE_CONDITIONS(
%   CONCENTRATION, TIME, CONDITIONS, EPOCH_WINDOW, SAMPLING_INTERVAL_S)
%   extracts complete epochs from continuous participant-level HbO and HbR
%   concentration data and calculates an arithmetic mean across included
%   trials for each already-detected condition.
%
%   Inputs:
%     CONCENTRATION      - Scalar structure containing finite, real,
%                          numeric HbO and HbR time-by-channel matrices and
%                          a finite channel-by-2 channel_pairs matrix.
%     TIME               - Finite, real, strictly increasing numeric time
%                          vector with one value per concentration row. Its
%                          units are seconds.
%     CONDITIONS         - Scalar structure returned by detect_conditions.
%                          Each stored condition supplies its name, onsets,
%                          durations, duration status, detected trial count,
%                          expected trial count, and expected-count status.
%     EPOCH_WINDOW       - Two-element [start end] vector in seconds, with
%                          start <= 0, end >= 0, and start < end.
%     SAMPLING_INTERVAL_S- Positive finite scalar sampling interval in
%                          seconds, normally taken from raw validation.
%
%   Outputs:
%     CONDITION_AVERAGES - Column struct array with name, time, HbO, HbR,
%                          and channel_pairs. HbO and HbR are epoch-time by
%                          channel averages, or [] when no complete trial
%                          is available.
%     EPOCH_REPORT       - Parallel column struct array with expected,
%                          detected, included, and excluded trial counts,
%                          detected-count QC, and excluded onset values.
%     COMPLETE_EPOCHS    - Optional parallel column struct array containing
%                          the complete, unaveraged HbO/HbR epochs as
%                          epoch-time-by-channel-by-trial arrays. The
%                          block_indices row vector gives each retained
%                          trial's original ordinal within its condition.
%
%   Onsets must equal sampled TIME values exactly. Epoch endpoints must lie
%   on the supplied sampling grid. Trials crossing a recording boundary are
%   excluded without padding. The function preserves channel and condition
%   order, uses onsets only for anchoring, and does not alter its inputs.
%   It performs no baseline correction, filtering, interpolation, channel
%   rejection, outlier processing, or group statistics.

if nargin ~= 5
    error('epoch_and_average_conditions:InvalidInputCount', ...
        'epoch_and_average_conditions requires exactly five inputs.');
end

[hbo, hbr, channel_pairs] = validate_concentration(concentration);
time_column = validate_time(time, size(hbo, 1));
validate_sampling_interval(sampling_interval_s, time_column);
[sample_offsets, epoch_time] = make_epoch_grid( ...
    epoch_window, sampling_interval_s);
[condition_fields, condition_values] = validate_conditions(conditions);

average_template = struct('name', '', 'time', [], 'HbO', [], ...
    'HbR', [], 'channel_pairs', []);
report_template = struct('name', '', 'expected_trial_count', [], ...
    'detected_trial_count', [], ...
    'detected_trial_count_matches_expected', [], ...
    'included_trial_count', [], 'excluded_trial_count', [], ...
    'excluded_trial_onsets', []);
epoch_template = struct('name', '', 'time', [], 'HbO', [], ...
    'HbR', [], 'channel_pairs', [], 'block_indices', []);
condition_count = numel(condition_fields);
condition_averages = repmat(average_template, condition_count, 1);
epoch_report = repmat(report_template, condition_count, 1);
complete_epochs = repmat(epoch_template, condition_count, 1);

time_count = size(hbo, 1);
channel_count = size(hbo, 2);
epoch_sample_count = numel(sample_offsets);

for condition_index = 1:condition_count
    condition = condition_values{condition_index};
    onsets = condition.onsets(:);
    [is_sampled, onset_rows] = ismember(onsets, time_column);
    if any(~is_sampled)
        error('epoch_and_average_conditions:OnsetNotSampled', ...
            'Every detected onset must exactly equal a sampled time value.');
    end

    complete_trial = onset_rows + sample_offsets(1) >= 1 & ...
        onset_rows + sample_offsets(end) <= time_count;
    included_rows = onset_rows(complete_trial);
    excluded_onsets = onsets(~complete_trial);
    included_trial_count = numel(included_rows);

    hbo_average = [];
    hbr_average = [];
    hbo_trials = zeros(epoch_sample_count, channel_count, 0, 'like', hbo);
    hbr_trials = zeros(epoch_sample_count, channel_count, 0, 'like', hbr);
    if included_trial_count > 0
        hbo_trials = zeros(epoch_sample_count, channel_count, ...
            included_trial_count, 'like', hbo);
        hbr_trials = zeros(epoch_sample_count, channel_count, ...
            included_trial_count, 'like', hbr);
        for trial_index = 1:included_trial_count
            epoch_rows = included_rows(trial_index) + sample_offsets;
            hbo_trials(:, :, trial_index) = hbo(epoch_rows, :);
            hbr_trials(:, :, trial_index) = hbr(epoch_rows, :);
        end
        hbo_average = mean(hbo_trials, 3);
        hbr_average = mean(hbr_trials, 3);
    end

    condition_averages(condition_index).name = condition.name;
    condition_averages(condition_index).time = epoch_time;
    condition_averages(condition_index).HbO = hbo_average;
    condition_averages(condition_index).HbR = hbr_average;
    condition_averages(condition_index).channel_pairs = channel_pairs;

    complete_epochs(condition_index).name = condition.name;
    complete_epochs(condition_index).time = epoch_time;
    complete_epochs(condition_index).HbO = hbo_trials;
    complete_epochs(condition_index).HbR = hbr_trials;
    complete_epochs(condition_index).channel_pairs = channel_pairs;
    complete_epochs(condition_index).block_indices = find(complete_trial).';

    detected_trial_count = numel(onsets);
    expected_trial_count = condition.expected_trial_count;
    epoch_report(condition_index).name = condition.name;
    epoch_report(condition_index).expected_trial_count = ...
        expected_trial_count;
    epoch_report(condition_index).detected_trial_count = ...
        detected_trial_count;
    epoch_report(condition_index).detected_trial_count_matches_expected = ...
        detected_trial_count == expected_trial_count;
    epoch_report(condition_index).included_trial_count = ...
        included_trial_count;
    epoch_report(condition_index).excluded_trial_count = ...
        detected_trial_count - included_trial_count;
    epoch_report(condition_index).excluded_trial_onsets = excluded_onsets;
end
end

function [hbo, hbr, channel_pairs] = validate_concentration(concentration)
required_fields = {'HbO', 'HbR', 'channel_pairs'};
if ~isstruct(concentration) || ~isscalar(concentration) || ...
        ~all(isfield(concentration, required_fields))
    error('epoch_and_average_conditions:InvalidConcentration', ...
        ['concentration must be a scalar structure containing HbO, HbR, ' ...
         'and channel_pairs.']);
end

hbo = concentration.HbO;
hbr = concentration.HbR;
if ~is_valid_data_matrix(hbo) || ~is_valid_data_matrix(hbr) || ...
        ~isequal(size(hbo), size(hbr))
    error('epoch_and_average_conditions:InvalidConcentration', ...
        ['HbO and HbR must be nonempty, finite, real, numeric 2-D ' ...
         'time-by-channel matrices with identical dimensions.']);
end

channel_pairs = concentration.channel_pairs;
if ~isnumeric(channel_pairs) || ~isreal(channel_pairs) || ...
        isempty(channel_pairs) || ~ismatrix(channel_pairs) || ...
        any(~isfinite(channel_pairs(:))) || size(channel_pairs, 2) ~= 2 || ...
        size(channel_pairs, 1) ~= size(hbo, 2)
    error('epoch_and_average_conditions:InvalidConcentration', ...
        ['channel_pairs must be a nonempty, finite, real, numeric ' ...
         'channel-by-2 matrix with one row per concentration channel.']);
end
end

function tf = is_valid_data_matrix(value)
tf = isnumeric(value) && isreal(value) && ~isempty(value) && ...
    ismatrix(value) && all(isfinite(value(:)));
end

function time_column = validate_time(time, expected_count)
if ~isnumeric(time) || ~isreal(time) || isempty(time) || ...
        ~isvector(time) || any(~isfinite(time(:)))
    error('epoch_and_average_conditions:InvalidTime', ...
        'time must be a nonempty, finite, real numeric vector.');
end
time_column = time(:);
if numel(time_column) ~= expected_count
    error('epoch_and_average_conditions:InvalidTime', ...
        'time must contain exactly one value per concentration row.');
end
if numel(time_column) < 2 || any(diff(time_column) <= 0)
    error('epoch_and_average_conditions:InvalidTime', ...
        'time must contain at least two strictly increasing samples.');
end
end

function validate_sampling_interval(sampling_interval_s, time_column)
if ~isnumeric(sampling_interval_s) || ~isreal(sampling_interval_s) || ...
        ~isscalar(sampling_interval_s) || ...
        ~isfinite(sampling_interval_s) || sampling_interval_s <= 0
    error('epoch_and_average_conditions:InvalidSamplingInterval', ...
        'sampling_interval_s must be a positive finite real numeric scalar.');
end

measured_interval = median(diff(time_column));
scale = max(abs([sampling_interval_s measured_interval]));
tolerance = 8 * eps(scale);
if abs(sampling_interval_s - measured_interval) > tolerance
    error('epoch_and_average_conditions:InvalidSamplingInterval', ...
        ['sampling_interval_s must agree with median(diff(time)) within ' ...
         'machine-precision representational tolerance.']);
end
end

function [sample_offsets, epoch_time] = make_epoch_grid( ...
        epoch_window, sampling_interval_s)
if ~isnumeric(epoch_window) || ~isreal(epoch_window) || ...
        ~isvector(epoch_window) || numel(epoch_window) ~= 2 || ...
        any(~isfinite(epoch_window(:)))
    error('epoch_and_average_conditions:InvalidEpochWindow', ...
        'epoch_window must contain exactly two finite real numeric values.');
end
epoch_window = epoch_window(:).';
if epoch_window(1) > 0 || epoch_window(2) < 0 || ...
        epoch_window(1) >= epoch_window(2)
    error('epoch_and_average_conditions:InvalidEpochWindow', ...
        ['epoch_window must satisfy start <= 0, end >= 0, and ' ...
         'start < end.']);
end

start_ratio = epoch_window(1) / sampling_interval_s;
end_ratio = epoch_window(2) / sampling_interval_s;
ratios = [start_ratio end_ratio];
if any(~isfinite(ratios)) || any(abs(ratios) > flintmax)
    error('epoch_and_average_conditions:InvalidEpochWindow', ...
        'epoch_window is too large for deterministic sample indexing.');
end
for ratio_index = 1:2
    ratio = ratios(ratio_index);
    tolerance = 8 * eps(max(1, abs(ratio)));
    if abs(ratio - round(ratio)) > tolerance
        error('epoch_and_average_conditions:EpochWindowNotOnSamplingGrid', ...
            ['Each epoch boundary must be representable as an integer ' ...
             'number of sampling intervals.']);
    end
end

start_offset = round(start_ratio);
end_offset = round(end_ratio);
sample_offsets = (start_offset:end_offset).';
epoch_time = sample_offsets * sampling_interval_s;
end

function [condition_fields, condition_values] = validate_conditions(conditions)
if ~isstruct(conditions) || ~isscalar(conditions)
    error('epoch_and_average_conditions:InvalidConditions', ...
        'conditions must be a scalar structure returned by detect_conditions.');
end
condition_fields = fieldnames(conditions);
if isempty(condition_fields)
    error('epoch_and_average_conditions:InvalidConditions', ...
        'conditions must contain at least one detected condition definition.');
end

required_fields = {'name', 'onsets', 'durations', 'has_durations', ...
    'trial_count', 'expected_trial_count', ...
    'trial_count_matches_expected'};
condition_values = cell(numel(condition_fields), 1);
for condition_index = 1:numel(condition_fields)
    field_name = condition_fields{condition_index};
    condition = conditions.(field_name);
    if ~isstruct(condition) || ~isscalar(condition) || ...
            ~all(isfield(condition, required_fields))
        invalid_conditions();
    end

    name_text = scalar_text(condition.name);
    if isempty(name_text) || ~strcmp(name_text, field_name)
        invalid_conditions();
    end

    onsets = condition.onsets;
    if ~isnumeric(onsets) || ~isreal(onsets) || ...
            ~(isvector(onsets) || isempty(onsets)) || ...
            any(~isfinite(onsets(:))) || any(onsets(:) < 0) || ...
            any(diff(onsets(:)) <= 0)
        invalid_conditions();
    end

    if ~is_nonnegative_integer(condition.trial_count) || ...
            condition.trial_count ~= numel(onsets) || ...
            ~is_nonnegative_integer(condition.expected_trial_count) || ...
            ~is_logical_compatible(condition.trial_count_matches_expected)
        invalid_conditions();
    end
    expected_match = condition.trial_count == condition.expected_trial_count;
    if logical(condition.trial_count_matches_expected) ~= expected_match
        invalid_conditions();
    end

    if ~is_logical_compatible(condition.has_durations)
        invalid_conditions();
    end
    durations = condition.durations;
    if logical(condition.has_durations)
        if ~isnumeric(durations) || ~isreal(durations) || ...
                ~isvector(durations) || isempty(durations) || ...
                any(~isfinite(durations(:))) || any(durations(:) < 0) || ...
                numel(durations) ~= numel(onsets)
            invalid_conditions();
        end
    elseif ~isempty(durations)
        invalid_conditions();
    end

    condition_values{condition_index} = condition;
end
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

function tf = is_nonnegative_integer(value)
tf = isnumeric(value) && isreal(value) && isscalar(value) && ...
    isfinite(value) && value >= 0 && fix(value) == value;
end

function tf = is_logical_compatible(value)
tf = (islogical(value) && isscalar(value)) || ...
    (isnumeric(value) && isreal(value) && isscalar(value) && ...
    isfinite(value) && (value == 0 || value == 1));
end

function invalid_conditions()
error('epoch_and_average_conditions:InvalidConditions', ...
    'conditions are inconsistent with the detect_conditions output contract.');
end

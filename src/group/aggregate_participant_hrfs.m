function group_result = aggregate_participant_hrfs( ...
        participant_results, group_config)
%AGGREGATE_PARTICIPANT_HRFS Aggregate compatible participant HRFs.
%   GROUP_RESULT = AGGREGATE_PARTICIPANT_HRFS(PARTICIPANT_RESULTS,
%   GROUP_CONFIG) aligns already-preprocessed participant conditions by
%   exact name, stacks finite HbO and HbR HRFs, and calls
%   pointwise_group_average independently for each chromophore.
%
%   Inputs:
%     PARTICIPANT_RESULTS - Struct vector with at least two elements. Each
%                           element contains a nonempty CONDITION_HRFS
%                           struct vector following the Stage D contract.
%                           Participant order defines mask dimension three.
%     GROUP_CONFIG        - Canonical group configuration declaring
%                           participant-condition input, pointwise mean/SD,
%                           strict threshold exclusion, no imputation, and
%                           recalculation after one-pass exclusion.
%
%   Output:
%     GROUP_RESULT.condition_hrfs - Final group HbO/HbR means in the first
%                                    participant's condition/channel order.
%     GROUP_RESULT.outlier_report - Parallel HbO/HbR pointwise audit masks,
%                                    statistics, and effective counts.
%     GROUP_RESULT.aggregation    - Exact aggregation-method metadata.
%
%   Time grids and channel order must agree exactly across participants.
%   Conditions are matched by exact full-string name equality. Inputs are
%   not modified, reordered in place, interpolated, or imputed. No SEM,
%   HbT, inferential statistics, or participant identifiers are returned.

if nargin ~= 2
    error('aggregate_participant_hrfs:InvalidInputCount', ...
        'aggregate_participant_hrfs requires exactly two inputs.');
end

threshold_sd = validate_group_config(group_config);
[reference_hrfs, reference_names] = ...
    validate_participant_container(participant_results);

participant_count = numel(participant_results);
condition_count = numel(reference_hrfs);
condition_template = struct('name', '', 'time', [], 'HbO', [], ...
    'HbR', [], 'channel_pairs', []);
outlier_template = struct('name', '', 'HbO', [], 'HbR', []);
condition_hrfs = repmat(condition_template, condition_count, 1);
outlier_report = repmat(outlier_template, condition_count, 1);

for condition_index = 1:condition_count
    reference = validate_condition_hrf(reference_hrfs(condition_index));
    time_count = size(reference.HbO, 1);
    channel_count = size(reference.HbO, 2);
    hbo_values = zeros(time_count, channel_count, participant_count, ...
        'like', reference.HbO);
    hbr_values = zeros(time_count, channel_count, participant_count, ...
        'like', reference.HbR);

    for participant_index = 1:participant_count
        participant_hrfs = participant_results(participant_index).condition_hrfs;
        matched_index = find_condition( ...
            participant_hrfs, reference_names{condition_index});
        current = validate_condition_hrf(participant_hrfs(matched_index));
        validate_compatibility(current, reference);
        hbo_values(:, :, participant_index) = current.HbO;
        hbr_values(:, :, participant_index) = current.HbR;
    end

    [hbo_mean, hbo_report] = pointwise_group_average( ...
        hbo_values, threshold_sd);
    [hbr_mean, hbr_report] = pointwise_group_average( ...
        hbr_values, threshold_sd);

    condition_hrfs(condition_index).name = reference.name;
    condition_hrfs(condition_index).time = reference.time(:);
    condition_hrfs(condition_index).HbO = hbo_mean;
    condition_hrfs(condition_index).HbR = hbr_mean;
    condition_hrfs(condition_index).channel_pairs = reference.channel_pairs;
    outlier_report(condition_index).name = reference.name;
    outlier_report(condition_index).HbO = hbo_report;
    outlier_report(condition_index).HbR = hbr_report;
end

aggregation = struct('participant_count', participant_count, ...
    'outlier_threshold_sd', threshold_sd, ...
    'sd_normalization', 'sample_n_minus_1', ...
    'outlier_comparison', 'strictly_greater_than', ...
    'iteration_policy', 'one_pass', 'imputation', 'none');
group_result = struct('condition_hrfs', condition_hrfs, ...
    'outlier_report', outlier_report, 'aggregation', aggregation);
end

function threshold_sd = validate_group_config(config)
required_fields = {'input_level', 'initial_statistics', ...
    'outlier_threshold_sd', 'outlier_rule', 'imputation', ...
    'recalculate_statistics_after_exclusion'};
if ~isstruct(config) || ~isscalar(config) || ...
        ~all(isfield(config, required_fields)) || ...
        ~text_equals(config.input_level, 'participant_condition_hrf') || ...
        ~iscell(config.initial_statistics) || ...
        ~isequal(config.initial_statistics, ...
        {'pointwise_mean', 'pointwise_sd'}) || ...
        ~text_equals(config.outlier_rule, ...
        'exclude_values_strictly_greater_than_threshold') || ...
        ~text_equals(config.imputation, 'none') || ...
        ~is_true_scalar(config.recalculate_statistics_after_exclusion)
    invalid_config();
end
threshold_sd = config.outlier_threshold_sd;
if ~isnumeric(threshold_sd) || ~isreal(threshold_sd) || ...
        ~isscalar(threshold_sd) || ~isfinite(threshold_sd) || ...
        threshold_sd <= 0
    invalid_config();
end
end

function [reference_hrfs, reference_names] = ...
        validate_participant_container(participant_results)
if ~isstruct(participant_results) || ~isvector(participant_results) || ...
        numel(participant_results) < 2 || ...
        ~isfield(participant_results, 'condition_hrfs')
    invalid_participants();
end
participant_results = participant_results(:);
for participant_index = 1:numel(participant_results)
    hrfs = participant_results(participant_index).condition_hrfs;
    if ~isstruct(hrfs) || ~isvector(hrfs) || isempty(hrfs)
        invalid_participants();
    end
end

reference_hrfs = participant_results(1).condition_hrfs(:);
reference_names = condition_names(reference_hrfs);
if numel(unique(reference_names)) ~= numel(reference_names)
    error('aggregate_participant_hrfs:IncompatibleConditions', ...
        'Condition names must be unique within each participant.');
end

for participant_index = 2:numel(participant_results)
    names = condition_names(participant_results(participant_index).condition_hrfs);
    if numel(names) ~= numel(reference_names) || ...
            numel(unique(names)) ~= numel(names) || ...
            ~all(ismember(reference_names, names)) || ...
            ~all(ismember(names, reference_names))
        error('aggregate_participant_hrfs:IncompatibleConditions', ...
            'Every participant must contain the same unique exact condition names.');
    end
end
end

function names = condition_names(hrfs)
hrfs = hrfs(:);
names = cell(numel(hrfs), 1);
for condition_index = 1:numel(hrfs)
    if ~isfield(hrfs(condition_index), 'name')
        invalid_participants();
    end
    names{condition_index} = scalar_text(hrfs(condition_index).name);
    if isempty(names{condition_index})
        invalid_participants();
    end
end
end

function index = find_condition(hrfs, name)
names = condition_names(hrfs);
matches = find(strcmp(names, name));
if numel(matches) ~= 1
    error('aggregate_participant_hrfs:IncompatibleConditions', ...
        'Each participant must contain exactly one exact condition-name match.');
end
index = matches(1);
end

function hrf = validate_condition_hrf(hrf)
required_fields = {'name', 'time', 'HbO', 'HbR', 'channel_pairs'};
if ~isstruct(hrf) || ~isscalar(hrf) || ...
        ~all(isfield(hrf, required_fields)) || isempty(scalar_text(hrf.name))
    invalid_participants();
end
hbo = hrf.HbO;
hbr = hrf.HbR;
if ~is_valid_matrix(hbo) || ~is_valid_matrix(hbr) || ...
        ~isequal(size(hbo), size(hbr))
    invalid_participants();
end
time = hrf.time;
if ~isnumeric(time) || ~isreal(time) || isempty(time) || ...
        ~isvector(time) || any(~isfinite(time(:))) || ...
        numel(time) ~= size(hbo, 1) || any(diff(time(:)) <= 0)
    invalid_participants();
end
pairs = hrf.channel_pairs;
if ~isnumeric(pairs) || ~isreal(pairs) || isempty(pairs) || ...
        ~ismatrix(pairs) || size(pairs, 2) ~= 2 || ...
        size(pairs, 1) ~= size(hbo, 2) || any(~isfinite(pairs(:))) || ...
        size(unique(pairs, 'rows'), 1) ~= size(pairs, 1)
    invalid_participants();
end
end

function validate_compatibility(current, reference)
if ~isequal(current.time(:), reference.time(:))
    error('aggregate_participant_hrfs:IncompatibleTime', ...
        'Matched participant conditions must use exactly equal time grids.');
end
if ~isequal(current.channel_pairs, reference.channel_pairs)
    error('aggregate_participant_hrfs:IncompatibleChannels', ...
        'Matched participant conditions must use identical channel order.');
end
if ~isequal(size(current.HbO), size(reference.HbO)) || ...
        ~isequal(size(current.HbR), size(reference.HbR))
    invalid_participants();
end
end

function tf = is_valid_matrix(value)
tf = isnumeric(value) && isreal(value) && ~isempty(value) && ...
    ismatrix(value) && all(isfinite(value(:)));
end

function tf = text_equals(value, expected)
text = scalar_text(value);
tf = ~isempty(text) && strcmp(text, expected);
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

function tf = is_true_scalar(value)
tf = (islogical(value) && isscalar(value) && value) || ...
    (isnumeric(value) && isreal(value) && isscalar(value) && ...
    isfinite(value) && value == 1);
end

function invalid_participants()
error('aggregate_participant_hrfs:InvalidParticipants', ...
    'participant_results are malformed or contain incompatible HRF dimensions.');
end

function invalid_config()
error('aggregate_participant_hrfs:InvalidConfig', ...
    'group_config is malformed or contradicts the canonical group method.');
end

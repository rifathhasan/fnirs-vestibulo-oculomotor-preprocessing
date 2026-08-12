function [conditions, report] = detect_conditions( ...
        stimuli, required_conditions, expected_trials)
%DETECT_CONDITIONS Detect required conditions by exact stimulus name.
%   [CONDITIONS, REPORT] = DETECT_CONDITIONS(STIMULI,
%   REQUIRED_CONDITIONS, EXPECTED_TRIALS) validates standardized in-memory
%   stimulus metadata and returns required conditions keyed by normalized
%   canonical name. No recording files are opened and no signal processing
%   is performed.
%
%   Inputs:
%     STIMULI            - Struct array with one stimulus definition per
%                          element. Each element has a scalar text NAME and
%                          a numeric vector ONSETS. DURATIONS is optional;
%                          an absent or empty value means unavailable.
%     REQUIRED_CONDITIONS- Nonempty vector or cell vector of scalar text
%                          names. Each upper(strtrim(name)) value must be a
%                          unique valid MATLAB structure field name.
%     EXPECTED_TRIALS    - Finite, real, nonnegative integer scalar used
%                          only for comparison with detected event counts.
%
%   Outputs:
%     CONDITIONS - Scalar structure keyed by normalized required name. Each
%                  condition contains NAME, ONSETS, DURATIONS,
%                  HAS_DURATIONS, TRIAL_COUNT, EXPECTED_TRIAL_COUNT, and
%                  TRIAL_COUNT_MATCHES_EXPECTED. Event vectors are columns.
%     REPORT     - Scalar structure containing UNEXPECTED_STIMULI,
%                  TRIAL_COUNT_MISMATCHES, and ALL_TRIAL_COUNTS_MATCH.
%
%   Onsets and durations use the time unit of the standardized metadata
%   (normally seconds). Onsets must be finite, real, nonnegative, and
%   strictly increasing. Supplied durations must be finite, real, and
%   nonnegative, with one value per onset. Events are not sorted, inferred,
%   interpolated, fabricated, or otherwise modified. Matching uses only
%   exact equality after upper(strtrim(name)); stimulus position is ignored.

if nargin ~= 3
    error('detect_conditions:InvalidInputCount', ...
        'detect_conditions requires exactly three inputs.');
end

normalized_required = validate_required_conditions(required_conditions);
validate_expected_trials(expected_trials);

if ~isstruct(stimuli) || ~isfield(stimuli, 'name') || ...
        ~isfield(stimuli, 'onsets')
    error('detect_conditions:InvalidStimuli', ...
        'stimuli must be a struct array with name and onsets fields.');
end
stimuli = stimuli(:);

stimulus_count = numel(stimuli);
normalized_stimulus = cell(stimulus_count, 1);
original_names = cell(stimulus_count, 1);
validated_onsets = cell(stimulus_count, 1);
validated_durations = cell(stimulus_count, 1);
has_durations = false(stimulus_count, 1);

durations_field_exists = isfield(stimuli, 'durations');
for stimulus_index = 1:stimulus_count
    [normalized_stimulus{stimulus_index}, original_names{stimulus_index}] = ...
        normalize_name(stimuli(stimulus_index).name, ...
        'detect_conditions:InvalidStimulusName');

    onsets = stimuli(stimulus_index).onsets;
    if ~isnumeric(onsets) || ~(isvector(onsets) || isempty(onsets)) || ...
            ~isreal(onsets) || any(~isfinite(onsets(:))) || ...
            any(onsets(:) < 0)
        error('detect_conditions:InvalidOnsets', ...
            ['Stimulus onsets must be a real, finite, nonnegative ' ...
             'numeric vector.']);
    end
    onsets = onsets(:);
    if any(diff(onsets) <= 0)
        error('detect_conditions:NonIncreasingOnsets', ...
            'Stimulus onsets must be strictly increasing.');
    end
    validated_onsets{stimulus_index} = onsets;

    durations = [];
    if durations_field_exists
        durations = stimuli(stimulus_index).durations;
    end
    if ~isempty(durations)
        if ~isnumeric(durations) || ~isvector(durations) || ...
                ~isreal(durations) || any(~isfinite(durations(:))) || ...
                any(durations(:) < 0)
            error('detect_conditions:InvalidDurations', ...
                ['Supplied durations must be a real, finite, nonnegative ' ...
                 'numeric vector.']);
        end
        durations = durations(:);
        if numel(durations) ~= numel(onsets)
            error('detect_conditions:OnsetDurationMismatch', ...
                'Supplied duration count must equal onset count.');
        end
        has_durations(stimulus_index) = true;
    end
    validated_durations{stimulus_index} = durations;
end

conditions = struct();
mismatch_template = struct('name', '', 'actual_trial_count', [], ...
    'expected_trial_count', []);
report.trial_count_mismatches = repmat(mismatch_template, 0, 1);

for required_index = 1:numel(normalized_required)
    canonical_name = normalized_required{required_index};
    matches = find(strcmp(normalized_stimulus, canonical_name));
    if isempty(matches)
        error('detect_conditions:MissingRequiredCondition', ...
            'Required condition "%s" is missing.', canonical_name);
    end
    if numel(matches) > 1
        error('detect_conditions:DuplicateRequiredCondition', ...
            'Required condition "%s" has duplicate definitions.', ...
            canonical_name);
    end

    stimulus_index = matches(1);
    actual_trial_count = numel(validated_onsets{stimulus_index});
    trial_count_matches = actual_trial_count == expected_trials;
    conditions.(canonical_name) = struct( ...
        'name', canonical_name, ...
        'onsets', validated_onsets{stimulus_index}, ...
        'durations', validated_durations{stimulus_index}, ...
        'has_durations', has_durations(stimulus_index), ...
        'trial_count', actual_trial_count, ...
        'expected_trial_count', expected_trials, ...
        'trial_count_matches_expected', trial_count_matches);

    if ~trial_count_matches
        mismatch = mismatch_template;
        mismatch.name = canonical_name;
        mismatch.actual_trial_count = actual_trial_count;
        mismatch.expected_trial_count = expected_trials;
        report.trial_count_mismatches(end + 1, 1) = mismatch;
    end
end

unexpected_template = struct('name', '', 'normalized_name', '', ...
    'stimulus_index', []);
report.unexpected_stimuli = repmat(unexpected_template, 0, 1);
is_required = ismember(normalized_stimulus, normalized_required);
unexpected_indices = find(~is_required);
for unexpected_index = 1:numel(unexpected_indices)
    stimulus_index = unexpected_indices(unexpected_index);
    unexpected = unexpected_template;
    unexpected.name = original_names{stimulus_index};
    unexpected.normalized_name = normalized_stimulus{stimulus_index};
    unexpected.stimulus_index = stimulus_index;
    report.unexpected_stimuli(end + 1, 1) = unexpected;
end
report.all_trial_counts_match = isempty(report.trial_count_mismatches);
end

function normalized_required = validate_required_conditions(required_conditions)
if ischar(required_conditions)
    if ~isvector(required_conditions) || isempty(required_conditions)
        error('detect_conditions:InvalidRequiredConditions', ...
            'required_conditions must contain nonempty scalar text names.');
    end
    required_items = {required_conditions};
elseif isstring(required_conditions)
    if ~isvector(required_conditions) || isempty(required_conditions)
        error('detect_conditions:InvalidRequiredConditions', ...
            'required_conditions must contain nonempty scalar text names.');
    end
    required_items = num2cell(required_conditions(:));
elseif iscell(required_conditions) && isvector(required_conditions) && ...
        ~isempty(required_conditions)
    required_items = required_conditions(:);
else
    error('detect_conditions:InvalidRequiredConditions', ...
        'required_conditions must be a nonempty vector of scalar text names.');
end

normalized_required = cell(size(required_items));
for required_index = 1:numel(required_items)
    normalized_required{required_index} = normalize_name( ...
        required_items{required_index}, ...
        'detect_conditions:InvalidRequiredConditions');
    if ~isvarname(normalized_required{required_index})
        error('detect_conditions:InvalidRequiredConditions', ...
            ['Each normalized required name must be a valid MATLAB ' ...
             'structure field name.']);
    end
end
if numel(unique(normalized_required)) ~= numel(normalized_required)
    error('detect_conditions:InvalidRequiredConditions', ...
        'Normalized required condition names must be unique.');
end
end

function validate_expected_trials(expected_trials)
if ~isnumeric(expected_trials) || ~isscalar(expected_trials) || ...
        ~isreal(expected_trials) || ~isfinite(expected_trials) || ...
        expected_trials < 0 || fix(expected_trials) ~= expected_trials
    error('detect_conditions:InvalidExpectedTrials', ...
        'expected_trials must be a finite, real, nonnegative integer scalar.');
end
end

function [normalized_name, original_name] = normalize_name(name, error_id)
if isstring(name)
    if ~isscalar(name) || ismissing(name)
        error(error_id, 'Condition names must be nonempty scalar text.');
    end
    original_name = char(name);
elseif ischar(name) && isvector(name) && ~isempty(name)
    original_name = name(:).';
else
    error(error_id, 'Condition names must be nonempty scalar text.');
end

normalized_name = upper(strtrim(original_name));
if isempty(normalized_name)
    error(error_id, 'Condition names must be nonempty scalar text.');
end
end

function tests = test_condition_detection
%TEST_CONDITION_DETECTION Synthetic tests for detect_conditions.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
test_file = mfilename('fullpath');
repository_root = fileparts(fileparts(test_file));
function_directory = fullfile(repository_root, 'src', 'individual');
path_entries = strsplit(path, pathsep);
testCase.TestData.function_directory = function_directory;
testCase.TestData.path_was_added = ~any(strcmp(path_entries, function_directory));
if testCase.TestData.path_was_added
    addpath(function_directory);
end
end

function teardownOnce(testCase)
if testCase.TestData.path_was_added
    rmpath(testCase.TestData.function_directory);
end
end

function testNormalOrderDetection(testCase)
stimuli = make_valid_stimuli();

[conditions, report] = detect_conditions(stimuli, required_names(), 5);

verifyEqual(testCase, fieldnames(conditions), {'EC'; 'HS'; 'HVOR'; 'VVOR'});
verifyEqual(testCase, conditions.EC.name, 'EC');
verifyEqual(testCase, conditions.HS.onsets, stimuli(2).onsets);
verifyTrue(testCase, report.all_trial_counts_match);
end

function testShuffledInputOrder(testCase)
stimuli = make_valid_stimuli();
stimuli = stimuli([3 1 4 2]);

conditions = detect_conditions(stimuli, required_names(), 5);

verifyEqual(testCase, conditions.EC.onsets, (0:4).');
verifyEqual(testCase, conditions.HS.onsets, (10:14).');
verifyEqual(testCase, conditions.HVOR.onsets, (20:24).');
verifyEqual(testCase, conditions.VVOR.onsets, (30:34).');
end

function testCaseInsensitiveStimulusMatching(testCase)
stimuli = make_valid_stimuli();
[stimuli.name] = deal('ec', 'Hs', 'hvor', 'vVoR');

conditions = detect_conditions(stimuli, required_names(), 5);

verifyEqual(testCase, fieldnames(conditions), {'EC'; 'HS'; 'HVOR'; 'VVOR'});
end

function testStimulusWhitespaceTrimming(testCase)
stimuli = make_valid_stimuli();
[stimuli.name] = deal(' EC ', '  HS', 'HVOR  ', '  VVOR  ');

conditions = detect_conditions(stimuli, required_names(), 5);

verifyEqual(testCase, conditions.EC.name, 'EC');
verifyEqual(testCase, conditions.VVOR.name, 'VVOR');
end

function testMissingEcDoesNotShiftLabels(testCase)
stimuli = make_valid_stimuli();
stimuli(1) = [];

verifyError(testCase, ...
    @() detect_conditions(stimuli, required_names(), 5), ...
    'detect_conditions:MissingRequiredCondition');
end

function testMissingRequiredConditionRaisesError(testCase)
stimuli = make_valid_stimuli();
stimuli(3) = [];

verifyError(testCase, ...
    @() detect_conditions(stimuli, required_names(), 5), ...
    'detect_conditions:MissingRequiredCondition');
end

function testDuplicateRequiredConditionRaisesError(testCase)
stimuli = make_valid_stimuli();
stimuli(5) = stimuli(1);
stimuli(5).name = ' ec ';

verifyError(testCase, ...
    @() detect_conditions(stimuli, required_names(), 5), ...
    'detect_conditions:DuplicateRequiredCondition');
end

function testUnexpectedStimulusReportedWithoutWarning(testCase)
stimuli = make_valid_stimuli();
stimuli(5) = struct('name', ' Calibration ', 'onsets', [40; 41], ...
    'durations', [1; 1]);
lastwarn('');

[conditions, report] = detect_conditions(stimuli, required_names(), 5);
[warning_message, warning_id] = lastwarn;

verifyFalse(testCase, isfield(conditions, 'CALIBRATION'));
verifyEqual(testCase, numel(report.unexpected_stimuli), 1);
verifyEqual(testCase, report.unexpected_stimuli.name, ' Calibration ');
verifyEqual(testCase, report.unexpected_stimuli.normalized_name, 'CALIBRATION');
verifyEqual(testCase, report.unexpected_stimuli.stimulus_index, 5);
verifyEqual(testCase, warning_message, '');
verifyEqual(testCase, warning_id, '');
end

function testTrialCountMismatchReportedWithoutWarning(testCase)
stimuli = make_valid_stimuli();
stimuli(1).onsets = stimuli(1).onsets(1:4);
stimuli(1).durations = stimuli(1).durations(1:4);
lastwarn('');

[conditions, report] = detect_conditions(stimuli, required_names(), 5);
[warning_message, warning_id] = lastwarn;

verifyEqual(testCase, conditions.EC.trial_count, 4);
verifyEqual(testCase, conditions.EC.expected_trial_count, 5);
verifyFalse(testCase, conditions.EC.trial_count_matches_expected);
verifyEqual(testCase, report.trial_count_mismatches.name, 'EC');
verifyEqual(testCase, report.trial_count_mismatches.actual_trial_count, 4);
verifyEqual(testCase, report.trial_count_mismatches.expected_trial_count, 5);
verifyFalse(testCase, report.all_trial_counts_match);
verifyEqual(testCase, warning_message, '');
verifyEqual(testCase, warning_id, '');
end

function testZeroEventConditionIsDetectedButReportedAsMismatch(testCase)
% A present zero-event definition is distinct from a missing definition.
stimuli = make_valid_stimuli();
stimuli(1).onsets = [];
stimuli(1).durations = [];

[conditions, report] = detect_conditions( ...
    stimuli, required_names(), 5);

verifyTrue(testCase, isfield(conditions, 'EC'));
verifyEqual(testCase, conditions.EC.name, 'EC');
verifyEmpty(testCase, conditions.EC.onsets);
verifyEqual(testCase, conditions.EC.trial_count, 0);
verifyEqual(testCase, conditions.EC.expected_trial_count, 5);
verifyFalse(testCase, conditions.EC.trial_count_matches_expected);
verifyFalse(testCase, report.all_trial_counts_match);
verifyEqual(testCase, numel(report.trial_count_mismatches), 1);
verifyEqual(testCase, report.trial_count_mismatches.name, 'EC');
verifyEqual(testCase, ...
    report.trial_count_mismatches.actual_trial_count, 0);
verifyEqual(testCase, ...
    report.trial_count_mismatches.expected_trial_count, 5);
end

function testInvalidOnsetValuesRaiseErrors(testCase)
invalid_onsets = {'invalid', [0; 1 + 1i], [0; NaN], [0; Inf], [-1; 0]};
for invalid_index = 1:numel(invalid_onsets)
    stimuli = make_valid_stimuli();
    stimuli(1).onsets = invalid_onsets{invalid_index};
    verifyError(testCase, ...
        @() detect_conditions(stimuli, required_names(), 5), ...
        'detect_conditions:InvalidOnsets');
end
end

function testNonIncreasingOnsetsRaiseErrors(testCase)
stimuli = make_valid_stimuli();
stimuli(1).onsets = [0; 1; 1; 3; 4];
verifyError(testCase, ...
    @() detect_conditions(stimuli, required_names(), 5), ...
    'detect_conditions:NonIncreasingOnsets');

stimuli = make_valid_stimuli();
stimuli(1).onsets = [0; 2; 1; 3; 4];
verifyError(testCase, ...
    @() detect_conditions(stimuli, required_names(), 5), ...
    'detect_conditions:NonIncreasingOnsets');
end

function testInvalidDurationValuesRaiseErrors(testCase)
invalid_durations = {'invalid', ones(5, 1) * (1 + 1i), ...
    [1; 1; NaN; 1; 1], [1; 1; Inf; 1; 1], [1; 1; -1; 1; 1]};
for invalid_index = 1:numel(invalid_durations)
    stimuli = make_valid_stimuli();
    stimuli(1).durations = invalid_durations{invalid_index};
    verifyError(testCase, ...
        @() detect_conditions(stimuli, required_names(), 5), ...
        'detect_conditions:InvalidDurations');
end
end

function testOnsetDurationMismatchRaisesError(testCase)
stimuli = make_valid_stimuli();
stimuli(1).durations = [1; 1; 1];

verifyError(testCase, ...
    @() detect_conditions(stimuli, required_names(), 5), ...
    'detect_conditions:OnsetDurationMismatch');
end

function testNoFuzzyOrPartialMatching(testCase)
stimuli = make_valid_stimuli();
stimuli(3).name = 'HVOR extra';

verifyError(testCase, ...
    @() detect_conditions(stimuli, required_names(), 5), ...
    'detect_conditions:MissingRequiredCondition');
end

function testTrialCountsEqualActualEvents(testCase)
stimuli = make_valid_stimuli();
stimuli(1).onsets = stimuli(1).onsets(1:3);
stimuli(1).durations = stimuli(1).durations(1:3);
stimuli(3).onsets = stimuli(3).onsets(1:4);
stimuli(3).durations = stimuli(3).durations(1:4);

conditions = detect_conditions(stimuli, required_names(), 5);

verifyEqual(testCase, conditions.EC.trial_count, ...
    numel(stimuli(1).onsets));
verifyEqual(testCase, conditions.HS.trial_count, ...
    numel(stimuli(2).onsets));
verifyEqual(testCase, conditions.HVOR.trial_count, ...
    numel(stimuli(3).onsets));
verifyEqual(testCase, conditions.VVOR.trial_count, ...
    numel(stimuli(4).onsets));
end

function testSuppliedDurationsArePreserved(testCase)
stimuli = make_valid_stimuli();
stimuli(2).durations = [0; 0.5; 1; 1.5; 2];

conditions = detect_conditions(stimuli, required_names(), 5);

verifyTrue(testCase, conditions.HS.has_durations);
verifyEqual(testCase, conditions.HS.durations, stimuli(2).durations);
end

function testUnavailableDurationsAreNotFabricated(testCase)
stimuli_without_field = rmfield(make_valid_stimuli(), 'durations');
conditions = detect_conditions(stimuli_without_field, required_names(), 5);
verifyFalse(testCase, conditions.EC.has_durations);
verifyEmpty(testCase, conditions.EC.durations);

stimuli_with_empty = make_valid_stimuli();
stimuli_with_empty(1).durations = [];
conditions = detect_conditions(stimuli_with_empty, required_names(), 5);
verifyFalse(testCase, conditions.EC.has_durations);
verifyEmpty(testCase, conditions.EC.durations);
end

function testRequiredNameNormalizationDefinesOutputFields(testCase)
stimuli = make_valid_stimuli();
required = {' ec ', 'hs', 'Hvor', ' vvor '};

conditions = detect_conditions(stimuli, required, 5);

verifyEqual(testCase, fieldnames(conditions), {'EC'; 'HS'; 'HVOR'; 'VVOR'});
verifyTrue(testCase, isfield(conditions, 'EC'));
verifyFalse(testCase, isfield(conditions, 'ec'));
end

function testInvalidRequiredConditionsRaiseErrors(testCase)
stimuli = make_valid_stimuli();

verifyError(testCase, ...
    @() detect_conditions(stimuli, {'EC', ' ec ', 'HVOR', 'VVOR'}, 5), ...
    'detect_conditions:InvalidRequiredConditions');
verifyError(testCase, ...
    @() detect_conditions(stimuli, {'E-C', 'HS', 'HVOR', 'VVOR'}, 5), ...
    'detect_conditions:InvalidRequiredConditions');
end

function testInvalidExpectedTrialsRaiseErrors(testCase)
stimuli = make_valid_stimuli();
invalid_expected = {-1, 1.5, Inf, NaN, [5 5], '5'};
for invalid_index = 1:numel(invalid_expected)
    verifyError(testCase, ...
        @() detect_conditions(stimuli, required_names(), ...
        invalid_expected{invalid_index}), ...
        'detect_conditions:InvalidExpectedTrials');
end
end

function stimuli = make_valid_stimuli()
names = {'EC', 'HS', 'HVOR', 'VVOR'};
stimuli = repmat(struct('name', '', 'onsets', [], 'durations', []), 1, 4);
for condition_index = 1:4
    first_onset = (condition_index - 1) * 10;
    stimuli(condition_index).name = names{condition_index};
    stimuli(condition_index).onsets = (first_onset:first_onset + 4).';
    stimuli(condition_index).durations = ones(5, 1);
end
end

function names = required_names()
names = {'EC', 'HS', 'HVOR', 'VVOR'};
end

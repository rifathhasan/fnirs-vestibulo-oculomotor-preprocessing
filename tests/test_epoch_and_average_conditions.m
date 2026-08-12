function tests = test_epoch_and_average_conditions
%TEST_EPOCH_AND_AVERAGE_CONDITIONS Synthetic Stage C contract tests.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
test_directory = fileparts(mfilename('fullpath'));
repository_root = fileparts(test_directory);
source_directory = fullfile(repository_root, 'src', 'individual');
addpath(source_directory);
testCase.TestData.source_directory = source_directory;
end

function teardownOnce(testCase)
rmpath(testCase.TestData.source_directory);
end

function testValidInputsAccepted(testCase)
[concentration, time, conditions, window, interval] = valid_inputs();
[averages, report] = call_epoch(concentration, time, conditions, window, interval);
verifySize(testCase, averages, [1 1]);
verifySize(testCase, report, [1 1]);
verifyEqual(testCase, averages.HbO, concentration.HbO(4:8, :));
end

function testInvalidInputCountRejected(testCase)
[concentration, time, conditions, window, ~] = valid_inputs();
verifyError(testCase, @() epoch_and_average_conditions( ...
    concentration, time, conditions, window), ...
    'epoch_and_average_conditions:InvalidInputCount');
end

function testTooManyInputsUseMatlabDispatchError(testCase)
[concentration, time, conditions, window, interval] = valid_inputs();
% MATLAB rejects excess arguments before this fixed-signature function body
% executes, so the native dispatch identifier is the expected contract.
verifyError(testCase, @() epoch_and_average_conditions( ...
    concentration, time, conditions, window, interval, true), ...
    'MATLAB:TooManyInputs');
end

function testMalformedConcentrationRejected(testCase)
[concentration, time, conditions, window, interval] = valid_inputs();
invalid = {[], struct(), struct('HbO', concentration.HbO, ...
    'HbR', concentration.HbR), concentration};
invalid{4}.HbO = 'not numeric';
for index = 1:numel(invalid)
    verifyError(testCase, @() call_epoch(invalid{index}, time, ...
        conditions, window, interval), ...
        'epoch_and_average_conditions:InvalidConcentration');
end
end

function testHbOHbRDimensionMismatchRejected(testCase)
[concentration, time, conditions, window, interval] = valid_inputs();
concentration.HbR = concentration.HbR(:, 1);
verifyError(testCase, @() call_epoch(concentration, time, conditions, ...
    window, interval), 'epoch_and_average_conditions:InvalidConcentration');
end

function testNonfiniteConcentrationRejected(testCase)
[concentration, time, conditions, window, interval] = valid_inputs();
concentration.HbO(1) = Inf;
verifyError(testCase, @() call_epoch(concentration, time, conditions, ...
    window, interval), 'epoch_and_average_conditions:InvalidConcentration');
end

function testChannelPairMetadataMismatchRejected(testCase)
[concentration, time, conditions, window, interval] = valid_inputs();
invalid = {concentration.channel_pairs(1, :), ...
    [concentration.channel_pairs zeros(2, 1)], ...
    [1 NaN; 2 3]};
for index = 1:numel(invalid)
    candidate = concentration;
    candidate.channel_pairs = invalid{index};
    verifyError(testCase, @() call_epoch(candidate, time, conditions, ...
        window, interval), ...
        'epoch_and_average_conditions:InvalidConcentration');
end
end

function testInvalidTimeRejected(testCase)
[concentration, time, conditions, window, interval] = valid_inputs();
invalid = {time.', [0; 1; 1; (3:10)'], ...
    [0; 1; NaN; (3:10)'], 'invalid'};
invalid{1}(5) = invalid{1}(4);
for index = 1:numel(invalid)
    verifyError(testCase, @() call_epoch(concentration, invalid{index}, ...
        conditions, window, interval), ...
        'epoch_and_average_conditions:InvalidTime');
end
end

function testTimeRowMismatchRejected(testCase)
[concentration, time, conditions, window, interval] = valid_inputs();
verifyError(testCase, @() call_epoch(concentration, time(1:end-1), ...
    conditions, window, interval), ...
    'epoch_and_average_conditions:InvalidTime');
end

function testInvalidConditionsRejected(testCase)
[concentration, time, conditions, window, interval] = valid_inputs();
empty_conditions = struct();
missing_fields.COND = struct('name', 'COND', 'onsets', 5);
wrong_name = conditions;
wrong_name.COND.name = 'OTHER';
wrong_count = conditions;
wrong_count.COND.trial_count = 2;
wrong_expected = conditions;
wrong_expected.COND.expected_trial_count = -1;
wrong_flag = conditions;
wrong_flag.COND.trial_count_matches_expected = false;
bad_duration = conditions;
bad_duration.COND.has_durations = true;
bad_duration.COND.durations = [];
invalid = {empty_conditions, missing_fields, wrong_name, wrong_count, ...
    wrong_expected, wrong_flag, bad_duration};
for index = 1:numel(invalid)
    verifyError(testCase, @() call_epoch(concentration, time, ...
        invalid{index}, window, interval), ...
        'epoch_and_average_conditions:InvalidConditions');
end
end

function testZeroDetectedAndExpectedTrialsRemainRepresented(testCase)
[concentration, time, ~, window, interval] = valid_inputs();
conditions = make_conditions('COND', [], 0, []);
[averages, report] = call_epoch( ...
    concentration, time, conditions, window, interval);
verifyEqual(testCase, averages.name, 'COND');
verifyEmpty(testCase, averages.HbO);
verifyEmpty(testCase, averages.HbR);
verifyEqual(testCase, report.detected_trial_count, 0);
verifyEqual(testCase, report.expected_trial_count, 0);
verifyTrue(testCase, report.detected_trial_count_matches_expected);
verifyEqual(testCase, report.included_trial_count, 0);
verifyEqual(testCase, report.excluded_trial_count, 0);
end

function testInvalidSamplingIntervalRejected(testCase)
[concentration, time, conditions, window, ~] = valid_inputs();
invalid = {0, -1, Inf, [1 1], 0.5};
for index = 1:numel(invalid)
    verifyError(testCase, @() call_epoch(concentration, time, conditions, ...
        window, invalid{index}), ...
        'epoch_and_average_conditions:InvalidSamplingInterval');
end
end

function testInvalidEpochWindowRejected(testCase)
[concentration, time, conditions, ~, interval] = valid_inputs();
invalid = {[1 2], [-2 -1], [0 0], [-1 0 1], [-1 NaN], 'bad'};
for index = 1:numel(invalid)
    verifyError(testCase, @() call_epoch(concentration, time, conditions, ...
        invalid{index}, interval), ...
        'epoch_and_average_conditions:InvalidEpochWindow');
end
end

function testEpochWindowOffSamplingGridRejected(testCase)
[concentration, time, conditions, ~, interval] = valid_inputs();
verifyError(testCase, @() call_epoch(concentration, time, conditions, ...
    [-1.5 2], interval), ...
    'epoch_and_average_conditions:EpochWindowNotOnSamplingGrid');
end

function testSampledOnsetAccepted(testCase)
[concentration, time, conditions, window, interval] = valid_inputs();
[~, report] = call_epoch(concentration, time, conditions, window, interval);
verifyEqual(testCase, report.detected_trial_count, 1);
verifyEqual(testCase, report.included_trial_count, 1);
end

function testNonsampledOnsetRejected(testCase)
[concentration, time, ~, window, interval] = valid_inputs();
conditions = make_conditions('COND', 5.5, 1, []);
verifyError(testCase, @() call_epoch(concentration, time, conditions, ...
    window, interval), 'epoch_and_average_conditions:OnsetNotSampled');
end

function testNearOnsetIsNotSnapped(testCase)
[concentration, time, ~, window, interval] = valid_inputs();
conditions = make_conditions('COND', 5 + eps(5), 1, []);
verifyError(testCase, @() call_epoch(concentration, time, conditions, ...
    window, interval), 'epoch_and_average_conditions:OnsetNotSampled');
end

function testMultipleOnsetsHandledIndependently(testCase)
[concentration, time, ~, ~, interval] = valid_inputs();
conditions = make_conditions('COND', [3; 7], 2, []);
[averages, report] = call_epoch(concentration, time, conditions, [-1 1], interval);
expected = (concentration.HbO(3:5, :) + concentration.HbO(7:9, :)) / 2;
verifyEqual(testCase, averages.HbO, expected);
verifyEqual(testCase, report.included_trial_count, 2);
end

function testConditionOrderPreserved(testCase)
[concentration, time, ~, window, interval] = valid_inputs();
conditions = struct();
conditions.SECOND = condition_value('SECOND', 5, 1, []);
conditions.FIRST = condition_value('FIRST', 6, 1, []);
[averages, report] = call_epoch(concentration, time, conditions, window, interval);
verifyEqual(testCase, {averages.name}.', {'SECOND'; 'FIRST'});
verifyEqual(testCase, {report.name}.', {'SECOND'; 'FIRST'});
end

function testConditionNamesPreservedExactly(testCase)
[concentration, time, ~, window, interval] = valid_inputs();
conditions.MixedCase = condition_value("MixedCase", 5, 1, []);
[averages, report] = call_epoch(concentration, time, conditions, window, interval);
verifyTrue(testCase, isequaln(averages.name, "MixedCase"));
verifyTrue(testCase, isequaln(report.name, "MixedCase"));
end

function testDurationsDoNotAffectEpochAnchors(testCase)
[concentration, time, ~, window, interval] = valid_inputs();
short_duration = make_conditions('COND', 5, 1, 0);
long_duration = make_conditions('COND', 5, 1, 100);
[short_average, ~] = call_epoch(concentration, time, short_duration, ...
    window, interval);
[long_average, ~] = call_epoch(concentration, time, long_duration, ...
    window, interval);
verifyEqual(testCase, short_average.HbO, long_average.HbO);
verifyEqual(testCase, short_average.HbR, long_average.HbR);
end

function testExactPreAndPostSampleCounts(testCase)
[concentration, time, conditions, ~, interval] = valid_inputs();
[averages, ~] = call_epoch(concentration, time, conditions, [-2 3], interval);
verifySize(testCase, averages.HbO, [6 2]);
verifyEqual(testCase, averages.time, (-2:3).');
end

function testBothEpochEndpointsIncluded(testCase)
[concentration, time, conditions, ~, interval] = valid_inputs();
[averages, ~] = call_epoch(concentration, time, conditions, [-2 3], interval);
verifyEqual(testCase, averages.HbO(1, :), concentration.HbO(4, :));
verifyEqual(testCase, averages.HbO(end, :), concentration.HbO(9, :));
end

function testEpochTimeVectorIsCorrect(testCase)
[concentration, time, ~, ~, ~] = valid_inputs();
conditions = make_conditions('COND', 0.5, 1, []);
small_time = (0:0.1:1).';
small_concentration = subset_concentration(concentration, numel(small_time));
[averages, ~] = call_epoch(small_concentration, small_time, conditions, ...
    [-0.2 0.3], 0.1);
verifyEqual(testCase, averages.time, (-2:3).' * 0.1, 'AbsTol', 1e-15);
end

function testHbOUsesCorrectSourceRows(testCase)
[concentration, time, conditions, window, interval] = valid_inputs();
[averages, ~] = call_epoch(concentration, time, conditions, window, interval);
verifyEqual(testCase, averages.HbO, concentration.HbO(4:8, :));
end

function testHbRUsesCorrectSourceRows(testCase)
[concentration, time, conditions, window, interval] = valid_inputs();
[averages, ~] = call_epoch(concentration, time, conditions, window, interval);
verifyEqual(testCase, averages.HbR, concentration.HbR(4:8, :));
end

function testMultipleChannelsRemainIndependent(testCase)
[concentration, time, conditions, window, interval] = valid_inputs();
[averages, ~] = call_epoch(concentration, time, conditions, window, interval);
verifyEqual(testCase, averages.HbO(:, 1), concentration.HbO(4:8, 1));
verifyEqual(testCase, averages.HbO(:, 2), concentration.HbO(4:8, 2));
verifyNotEqual(testCase, averages.HbO(:, 1), averages.HbO(:, 2));
end

function testChannelOrderPreservedExactly(testCase)
[concentration, time, conditions, window, interval] = valid_inputs();
saved_pairs = concentration.channel_pairs;
[averages, ~] = call_epoch(concentration, time, conditions, window, interval);
verifyTrue(testCase, isequaln(averages.channel_pairs, saved_pairs));
verifyEqual(testCase, averages.HbO, concentration.HbO(4:8, :));
end

function testEarlyIncompleteTrialExcluded(testCase)
[concentration, time, ~, window, interval] = valid_inputs();
conditions = make_conditions('COND', 1, 1, []);
[averages, report] = call_epoch(concentration, time, conditions, window, interval);
verifyEmpty(testCase, averages.HbO);
verifyEqual(testCase, report.excluded_trial_onsets, 1);
end

function testLateIncompleteTrialExcluded(testCase)
[concentration, time, ~, window, interval] = valid_inputs();
conditions = make_conditions('COND', 9, 1, []);
[averages, report] = call_epoch(concentration, time, conditions, window, interval);
verifyEmpty(testCase, averages.HbR);
verifyEqual(testCase, report.excluded_trial_onsets, 9);
end

function testCompleteTrialAveragedWhenAnotherExcluded(testCase)
[concentration, time, ~, window, interval] = valid_inputs();
conditions = make_conditions('COND', [1; 5], 2, []);
[averages, report] = call_epoch(concentration, time, conditions, window, interval);
verifyEqual(testCase, averages.HbO, concentration.HbO(4:8, :));
verifyEqual(testCase, report.included_trial_count, 1);
end

function testTrialAccountingCountsAreCorrect(testCase)
[concentration, time, ~, window, interval] = valid_inputs();
conditions = make_conditions('COND', [1; 5; 9], 3, []);
[~, report] = call_epoch(concentration, time, conditions, window, interval);
verifyEqual(testCase, report.detected_trial_count, 3);
verifyEqual(testCase, report.included_trial_count, 1);
verifyEqual(testCase, report.excluded_trial_count, 2);
end

function testExcludedTrialOnsetsAreExact(testCase)
[concentration, time, ~, window, interval] = valid_inputs();
conditions = make_conditions('COND', [1; 5; 9], 3, []);
[~, report] = call_epoch(concentration, time, conditions, window, interval);
verifyEqual(testCase, report.excluded_trial_onsets, [1; 9]);
end

function testBoundaryEpochsAreNotPaddedOrShortened(testCase)
[concentration, time, ~, window, interval] = valid_inputs();
conditions = make_conditions('COND', [1; 5], 2, []);
[averages, report] = call_epoch(concentration, time, conditions, window, interval);
verifySize(testCase, averages.HbO, [5 2]);
verifyEqual(testCase, averages.time, (-2:2).');
verifyEqual(testCase, report.excluded_trial_count, 1);
end

function testSingleIncludedTrialEqualsExtractedTrial(testCase)
[concentration, time, conditions, window, interval] = valid_inputs();
[averages, ~] = call_epoch(concentration, time, conditions, window, interval);
verifyEqual(testCase, averages.HbO, concentration.HbO(4:8, :));
verifyEqual(testCase, averages.HbR, concentration.HbR(4:8, :));
end

function testMultipleIncludedTrialsUseArithmeticMean(testCase)
[concentration, time, ~, ~, interval] = valid_inputs();
conditions = make_conditions('COND', [3; 7], 2, []);
[averages, ~] = call_epoch(concentration, time, conditions, [-1 1], interval);
expected_hbo = (concentration.HbO(3:5, :) + ...
    concentration.HbO(7:9, :)) / 2;
verifyEqual(testCase, averages.HbO, expected_hbo);
end

function testHbOAndHbRAveragedIndependently(testCase)
[concentration, time, ~, ~, interval] = valid_inputs();
conditions = make_conditions('COND', [3; 7], 2, []);
[averages, ~] = call_epoch(concentration, time, conditions, [-1 1], interval);
expected_hbo = (concentration.HbO(3:5, :) + concentration.HbO(7:9, :)) / 2;
expected_hbr = (concentration.HbR(3:5, :) + concentration.HbR(7:9, :)) / 2;
verifyEqual(testCase, averages.HbO, expected_hbo);
verifyEqual(testCase, averages.HbR, expected_hbr);
end

function testNoTrialWeighting(testCase)
time = (0:8).';
concentration.HbO = [time.^2, 100 + time.^2];
concentration.HbR = [-time.^2, 50 - time.^2];
concentration.channel_pairs = [4 2; 1 3];
conditions = make_conditions('COND', [2; 4; 6], 3, []);
[averages, ~] = call_epoch(concentration, time, conditions, [0 1], 1);
expected = (concentration.HbO(3:4, :) + ...
    concentration.HbO(5:6, :) + concentration.HbO(7:8, :)) / 3;
verifyEqual(testCase, averages.HbO, expected);
end

function testNaNIsRejectedRatherThanOmitted(testCase)
[concentration, time, conditions, window, interval] = valid_inputs();
concentration.HbR(5, 1) = NaN;
verifyError(testCase, @() call_epoch(concentration, time, conditions, ...
    window, interval), 'epoch_and_average_conditions:InvalidConcentration');
end

function testPrestimulusOffsetRemainsWithoutBaselineCorrection(testCase)
time = (0:8).';
concentration.HbO = repmat([12 25], numel(time), 1);
concentration.HbR = repmat([-3 7], numel(time), 1);
concentration.channel_pairs = [3 1; 2 4];
conditions = make_conditions('COND', [3; 5], 2, []);
[averages, ~] = call_epoch(concentration, time, conditions, [-2 2], 1);
verifyEqual(testCase, averages.HbO, repmat([12 25], 5, 1));
verifyEqual(testCase, averages.HbR, repmat([-3 7], 5, 1));
verifyNotEqual(testCase, mean(averages.HbO(1:2, :), 1), [0 0]);
end

function testZeroDetectedEventsRemainRepresented(testCase)
[concentration, time, ~, window, interval] = valid_inputs();
conditions = make_conditions('COND', [], 5, []);
[averages, report] = call_epoch(concentration, time, conditions, window, interval);
verifyEqual(testCase, averages.name, 'COND');
verifyEqual(testCase, averages.time, (-2:2).');
verifyEmpty(testCase, averages.HbO);
verifyEqual(testCase, report.detected_trial_count, 0);
end

function testAllDetectedTrialsExcludedRemainRepresented(testCase)
[concentration, time, ~, window, interval] = valid_inputs();
conditions = make_conditions('COND', [0; 10], 2, []);
[averages, report] = call_epoch(concentration, time, conditions, window, interval);
verifyEqual(testCase, averages.name, 'COND');
verifyEqual(testCase, report.included_trial_count, 0);
verifyEqual(testCase, report.excluded_trial_onsets, [0; 10]);
end

function testZeroIncludedTrialsDoNotFabricateHrf(testCase)
[concentration, time, ~, window, interval] = valid_inputs();
conditions = make_conditions('COND', [0; 10], 2, []);
[averages, ~] = call_epoch(concentration, time, conditions, window, interval);
verifyTrue(testCase, isequal(averages.HbO, []));
verifyTrue(testCase, isequal(averages.HbR, []));
verifyEqual(testCase, averages.channel_pairs, concentration.channel_pairs);
end

function testExpectedAndDetectedCountsRemainDistinct(testCase)
[concentration, time, ~, window, interval] = valid_inputs();
conditions = make_conditions('COND', 5, 5, []);
[~, report] = call_epoch(concentration, time, conditions, window, interval);
verifyEqual(testCase, report.expected_trial_count, 5);
verifyEqual(testCase, report.detected_trial_count, 1);
verifyFalse(testCase, report.detected_trial_count_matches_expected);
end

function testDetectedCountQcRemainsDistinctFromIncludedCount(testCase)
[concentration, time, ~, window, interval] = valid_inputs();
conditions = make_conditions('COND', [0; 5], 2, []);
[~, report] = call_epoch(concentration, time, conditions, window, interval);
verifyTrue(testCase, report.detected_trial_count_matches_expected);
verifyEqual(testCase, report.detected_trial_count, 2);
verifyEqual(testCase, report.included_trial_count, 1);
end

function testInputsRemainUnchanged(testCase)
[concentration, time, conditions, window, interval] = valid_inputs();
saved_concentration = concentration;
saved_time = time;
saved_conditions = conditions;
saved_window = window;
call_epoch(concentration, time, conditions, window, interval);
verifyTrue(testCase, isequaln(concentration, saved_concentration));
verifyTrue(testCase, isequaln(time, saved_time));
verifyTrue(testCase, isequaln(conditions, saved_conditions));
verifyTrue(testCase, isequaln(window, saved_window));
end

function testOutputContainsOnlyApprovedFields(testCase)
[concentration, time, conditions, window, interval] = valid_inputs();
[averages, report] = call_epoch(concentration, time, conditions, window, interval);
verifyEqual(testCase, fieldnames(averages), ...
    {'name'; 'time'; 'HbO'; 'HbR'; 'channel_pairs'});
verifyEqual(testCase, fieldnames(report), ...
    {'name'; 'expected_trial_count'; 'detected_trial_count'; ...
     'detected_trial_count_matches_expected'; 'included_trial_count'; ...
     'excluded_trial_count'; 'excluded_trial_onsets'});
end

function testOptionalCompleteEpochOutputPreservesTrialAndOrdinal(testCase)
[concentration, time, ~, window, interval] = valid_inputs();
conditions = make_conditions('COND', [1 5 9], 3, []);
[~, ~, complete_epochs] = epoch_and_average_conditions( ...
    concentration, time, conditions, window, interval);
verifyEqual(testCase, fieldnames(complete_epochs), ...
    {'name'; 'time'; 'HbO'; 'HbR'; 'channel_pairs'; 'block_indices'});
verifyEqual(testCase, complete_epochs.name, 'COND');
verifyEqual(testCase, complete_epochs.time, (-2:2).');
verifyEqual(testCase, complete_epochs.HbO(:, :, 1), ...
    concentration.HbO(4:8, :));
verifyEqual(testCase, complete_epochs.HbR(:, :, 1), ...
    concentration.HbR(4:8, :));
verifyEqual(testCase, size(complete_epochs.HbO, 3), 1);
verifyEqual(testCase, complete_epochs.channel_pairs, ...
    concentration.channel_pairs);
verifyEqual(testCase, complete_epochs.block_indices, 2);
end

function testOptionalCompleteEpochOutputPreservesMultipleTrialOrder(testCase)
[concentration, time, ~, ~, interval] = valid_inputs();
conditions = make_conditions('COND', [3 7], 2, []);
[~, ~, complete_epochs] = epoch_and_average_conditions( ...
    concentration, time, conditions, [-1 1], interval);
verifySize(testCase, complete_epochs.HbO, [3 2 2]);
verifyEqual(testCase, complete_epochs.HbO(:, :, 1), ...
    concentration.HbO(3:5, :));
verifyEqual(testCase, complete_epochs.HbO(:, :, 2), ...
    concentration.HbO(7:9, :));
verifyEqual(testCase, complete_epochs.HbR(:, :, 1), ...
    concentration.HbR(3:5, :));
verifyEqual(testCase, complete_epochs.HbR(:, :, 2), ...
    concentration.HbR(7:9, :));
verifyEqual(testCase, complete_epochs.block_indices, [1 2]);
end

function testExistingTwoOutputCallRemainsUnchanged(testCase)
[concentration, time, conditions, window, interval] = valid_inputs();
[old_averages, old_report] = epoch_and_average_conditions( ...
    concentration, time, conditions, window, interval);
[new_averages, new_report, ~] = epoch_and_average_conditions( ...
    concentration, time, conditions, window, interval);
verifyTrue(testCase, isequaln(old_averages, new_averages));
verifyTrue(testCase, isequaln(old_report, new_report));
end

function [concentration, time, conditions, window, interval] = valid_inputs()
time = (0:10).';
concentration.HbO = [time, 100 + 2 * time];
concentration.HbR = [-time, 50 - 3 * time];
% Synthetic channel identities are test-only and not study geometry.
concentration.channel_pairs = [4 2; 1 3];
conditions = make_conditions('COND', 5, 1, []);
window = [-2 2];
interval = 1;
end

function conditions = make_conditions(name, onsets, expected_count, durations)
conditions = struct();
conditions.(char(name)) = condition_value(name, onsets, expected_count, durations);
end

function condition = condition_value(name, onsets, expected_count, durations)
onsets = onsets(:);
durations = durations(:);
has_durations = ~isempty(durations);
detected_count = numel(onsets);
condition = struct('name', name, 'onsets', onsets, ...
    'durations', durations, 'has_durations', has_durations, ...
    'trial_count', detected_count, ...
    'expected_trial_count', expected_count, ...
    'trial_count_matches_expected', detected_count == expected_count);
end

function concentration = subset_concentration(source, sample_count)
concentration.HbO = source.HbO(1:sample_count, :);
concentration.HbR = source.HbR(1:sample_count, :);
concentration.channel_pairs = source.channel_pairs;
end

function [averages, report] = call_epoch( ...
        concentration, time, conditions, window, interval)
[averages, report] = epoch_and_average_conditions( ...
    concentration, time, conditions, window, interval);
end

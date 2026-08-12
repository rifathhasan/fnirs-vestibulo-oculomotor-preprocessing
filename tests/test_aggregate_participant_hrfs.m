function tests = test_aggregate_participant_hrfs
%TEST_AGGREGATE_PARTICIPANT_HRFS Synthetic cohort aggregation tests.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
test_directory = fileparts(mfilename('fullpath'));
repository_root = fileparts(test_directory);
source_directory = fullfile(repository_root, 'src', 'group');
addpath(source_directory);
testCase.TestData.source_directory = source_directory;
end

function teardownOnce(testCase)
rmpath(testCase.TestData.source_directory);
end

function testValidParticipantAggregation(testCase)
[participants, config] = valid_inputs(6);
result = aggregate_participant_hrfs(participants, config);
verifySize(testCase, result.condition_hrfs, [2 1]);
verifyEqual(testCase, result.condition_hrfs(1).HbO, ...
    mean(stack_chromophore(participants, 'A', 'HbO'), 3));
verifyEqual(testCase, result.condition_hrfs(1).HbR, ...
    mean(stack_chromophore(participants, 'A', 'HbR'), 3));
end

function testApprovedTopLevelFields(testCase)
[participants, config] = valid_inputs(2);
result = aggregate_participant_hrfs(participants, config);
verifyEqual(testCase, fieldnames(result), ...
    {'condition_hrfs'; 'outlier_report'; 'aggregation'});
end

function testApprovedConditionHrfFields(testCase)
[participants, config] = valid_inputs(2);
result = aggregate_participant_hrfs(participants, config);
verifyEqual(testCase, fieldnames(result.condition_hrfs), ...
    {'name'; 'time'; 'HbO'; 'HbR'; 'channel_pairs'});
end

function testApprovedOutlierReportFields(testCase)
[participants, config] = valid_inputs(2);
result = aggregate_participant_hrfs(participants, config);
verifyEqual(testCase, fieldnames(result.outlier_report), ...
    {'name'; 'HbO'; 'HbR'});
verifyEqual(testCase, fieldnames(result.outlier_report(1).HbO), ...
    {'threshold_sd'; 'initial_mean'; 'initial_sd'; 'final_sd'; ...
     'outlier_mask'; 'n_included'; 'n_excluded'});
end

function testApprovedAggregationFieldsAndValues(testCase)
[participants, config] = valid_inputs(3);
result = aggregate_participant_hrfs(participants, config);
verifyEqual(testCase, fieldnames(result.aggregation), ...
    {'participant_count'; 'outlier_threshold_sd'; 'sd_normalization'; ...
     'outlier_comparison'; 'iteration_policy'; 'imputation'});
verifyEqual(testCase, result.aggregation.participant_count, 3);
verifyEqual(testCase, result.aggregation.outlier_threshold_sd, ...
    config.outlier_threshold_sd);
verifyEqual(testCase, result.aggregation.sd_normalization, ...
    'sample_n_minus_1');
verifyEqual(testCase, result.aggregation.outlier_comparison, ...
    'strictly_greater_than');
verifyEqual(testCase, result.aggregation.iteration_policy, 'one_pass');
verifyEqual(testCase, result.aggregation.imputation, 'none');
end

function testTooFewInputsRejected(testCase)
[participants, ~] = valid_inputs(2);
verifyError(testCase, @() aggregate_participant_hrfs(participants), ...
    'aggregate_participant_hrfs:InvalidInputCount');
end

function testTooManyInputsUseMatlabDispatchError(testCase)
[participants, config] = valid_inputs(2);
verifyError(testCase, @() aggregate_participant_hrfs( ...
    participants, config, true), 'MATLAB:TooManyInputs');
end

function testMalformedParticipantsRejected(testCase)
[participants, config] = valid_inputs(2);
invalid = {[], 'participants', struct('other', 1), participants};
invalid{4}(2).condition_hrfs = struct([]);
for index = 1:numel(invalid)
    verifyError(testCase, @() aggregate_participant_hrfs( ...
        invalid{index}, config), ...
        'aggregate_participant_hrfs:InvalidParticipants');
end
end

function testNonfiniteOrComplexHrfValuesRejected(testCase)
[participants, config] = valid_inputs(2);
invalid = {participants, participants, participants};
invalid{1}(1).condition_hrfs(1).HbO(1) = NaN;
invalid{2}(1).condition_hrfs(1).HbR(1) = Inf;
invalid{3}(1).condition_hrfs(1).HbO = ...
    invalid{3}(1).condition_hrfs(1).HbO + 1i;
for index = 1:numel(invalid)
    verifyError(testCase, @() aggregate_participant_hrfs( ...
        invalid{index}, config), ...
        'aggregate_participant_hrfs:InvalidParticipants');
end
end

function testMalformedTimeRejected(testCase)
[participants, config] = valid_inputs(2);
invalid = {participants, participants, participants};
invalid{1}(1).condition_hrfs(1).time(2) = NaN;
invalid{2}(1).condition_hrfs(1).time = [0; 0; 1];
invalid{3}(1).condition_hrfs(1).time = [0; 1];
for index = 1:numel(invalid)
    verifyError(testCase, @() aggregate_participant_hrfs( ...
        invalid{index}, config), ...
        'aggregate_participant_hrfs:InvalidParticipants');
end
end

function testMalformedChannelMetadataRejected(testCase)
[participants, config] = valid_inputs(2);
invalid = {participants, participants, participants};
invalid{1}(1).condition_hrfs(1).channel_pairs(1) = NaN;
invalid{2}(1).condition_hrfs(1).channel_pairs = ones(2, 3);
invalid{3}(1).condition_hrfs(1).channel_pairs = [1 2];
for index = 1:numel(invalid)
    verifyError(testCase, @() aggregate_participant_hrfs( ...
        invalid{index}, config), ...
        'aggregate_participant_hrfs:InvalidParticipants');
end
end

function testOneParticipantRejected(testCase)
[participants, config] = valid_inputs(2);
verifyError(testCase, @() aggregate_participant_hrfs( ...
    participants(1), config), ...
    'aggregate_participant_hrfs:InvalidParticipants');
end

function testMalformedConfigRejected(testCase)
[participants, config] = valid_inputs(2);
invalid = {struct(), config, config, config, config, config, config};
invalid{2}.input_level = 'continuous';
invalid{3}.initial_statistics = {'pointwise_mean'};
invalid{4}.outlier_threshold_sd = 0;
invalid{5}.outlier_rule = 'greater_or_equal';
invalid{6}.imputation = 'mean';
invalid{7}.recalculate_statistics_after_exclusion = false;
for index = 1:numel(invalid)
    verifyError(testCase, @() aggregate_participant_hrfs( ...
        participants, invalid{index}), ...
        'aggregate_participant_hrfs:InvalidConfig');
end
end

function testCanonicalGroupConfigSemanticsAccepted(testCase)
[participants, config] = valid_inputs(2);
result = aggregate_participant_hrfs(participants, config);
verifyEqual(testCase, result.aggregation.outlier_threshold_sd, 2);
verifyEqual(testCase, result.aggregation.imputation, 'none');
end

function testHbOAndHbRAreProcessedIndependently(testCase)
[participants, config] = valid_inputs(6);
for participant_index = 1:6
    participants(participant_index).condition_hrfs(1).HbO(1, 1) = 0;
    participants(participant_index).condition_hrfs(1).HbR(1, 1) = 0;
end
participants(6).condition_hrfs(1).HbO(1, 1) = 10;
result = aggregate_participant_hrfs(participants, config);
verifyTrue(testCase, result.outlier_report(1).HbO.outlier_mask(1, 1, 6));
verifyFalse(testCase, any( ...
    result.outlier_report(1).HbR.outlier_mask(1, 1, :), 'all'));
end

function testExclusionIsIndependentAcrossConditions(testCase)
[participants, config] = valid_inputs(6);
for participant_index = 1:6
    participants(participant_index).condition_hrfs(1).HbO(1, 1) = 0;
    participants(participant_index).condition_hrfs(2).HbO(1, 1) = 0;
end
participants(6).condition_hrfs(1).HbO(1, 1) = 10;
result = aggregate_participant_hrfs(participants, config);
verifyTrue(testCase, result.outlier_report(1).HbO.outlier_mask(1, 1, 6));
verifyFalse(testCase, any( ...
    result.outlier_report(2).HbO.outlier_mask(1, 1, :), 'all'));
end

function testFirstParticipantConditionOrderPreserved(testCase)
[participants, config] = valid_inputs(2);
participants(1).condition_hrfs = participants(1).condition_hrfs([2 1]);
result = aggregate_participant_hrfs(participants, config);
verifyEqual(testCase, {result.condition_hrfs.name}.', {'B'; 'A'});
verifyEqual(testCase, {result.outlier_report.name}.', {'B'; 'A'});
end

function testLaterParticipantConditionOrderMayDiffer(testCase)
[participants, config] = valid_inputs(2);
participants(2).condition_hrfs = participants(2).condition_hrfs([2 1]);
result = aggregate_participant_hrfs(participants, config);
verifyEqual(testCase, {result.condition_hrfs.name}.', {'A'; 'B'});
expected = mean(cat(3, participants(1).condition_hrfs(1).HbO, ...
    participants(2).condition_hrfs(2).HbO), 3);
verifyEqual(testCase, result.condition_hrfs(1).HbO, expected);
end

function testConditionNamesRequireExactCase(testCase)
[participants, config] = valid_inputs(2);
participants(2).condition_hrfs(1).name = 'a';
verifyError(testCase, @() aggregate_participant_hrfs( ...
    participants, config), ...
    'aggregate_participant_hrfs:IncompatibleConditions');
end

function testConditionNamesAreNotTrimmed(testCase)
[participants, config] = valid_inputs(2);
participants(2).condition_hrfs(1).name = ' A ';
verifyError(testCase, @() aggregate_participant_hrfs( ...
    participants, config), ...
    'aggregate_participant_hrfs:IncompatibleConditions');
end

function testMissingConditionRejected(testCase)
[participants, config] = valid_inputs(2);
participants(2).condition_hrfs(2) = [];
verifyError(testCase, @() aggregate_participant_hrfs( ...
    participants, config), ...
    'aggregate_participant_hrfs:IncompatibleConditions');
end

function testUnexpectedConditionRejected(testCase)
[participants, config] = valid_inputs(2);
extra = participants(2).condition_hrfs(1);
extra.name = 'C';
participants(2).condition_hrfs(3) = extra;
verifyError(testCase, @() aggregate_participant_hrfs( ...
    participants, config), ...
    'aggregate_participant_hrfs:IncompatibleConditions');
end

function testDuplicateConditionRejected(testCase)
[participants, config] = valid_inputs(2);
participants(2).condition_hrfs(2).name = 'A';
verifyError(testCase, @() aggregate_participant_hrfs( ...
    participants, config), ...
    'aggregate_participant_hrfs:IncompatibleConditions');
end

function testIncompatibleTimeRejected(testCase)
[participants, config] = valid_inputs(2);
participants(2).condition_hrfs(1).time(2) = 0.25;
verifyError(testCase, @() aggregate_participant_hrfs( ...
    participants, config), ...
    'aggregate_participant_hrfs:IncompatibleTime');
end

function testRowColumnTimeOrientationDifferenceAccepted(testCase)
[participants, config] = valid_inputs(2);
participants(2).condition_hrfs(1).time = ...
    participants(2).condition_hrfs(1).time.';
result = aggregate_participant_hrfs(participants, config);
verifySize(testCase, result.condition_hrfs(1).time, [3 1]);
verifyEqual(testCase, result.condition_hrfs(1).time, [-1; 0; 1]);
end

function testIncompatibleHrfDimensionsRejected(testCase)
[participants, config] = valid_inputs(2);
participants(2).condition_hrfs(1).HbR = ones(3, 1);
verifyError(testCase, @() aggregate_participant_hrfs( ...
    participants, config), ...
    'aggregate_participant_hrfs:InvalidParticipants');
end

function testDifferentChannelSetRejected(testCase)
[participants, config] = valid_inputs(2);
participants(2).condition_hrfs(1).channel_pairs(2, :) = [9 9];
verifyError(testCase, @() aggregate_participant_hrfs( ...
    participants, config), ...
    'aggregate_participant_hrfs:IncompatibleChannels');
end

function testDifferentChannelOrderRejected(testCase)
[participants, config] = valid_inputs(2);
participants(2).condition_hrfs(1).channel_pairs = ...
    participants(2).condition_hrfs(1).channel_pairs([2 1], :);
participants(2).condition_hrfs(1).HbO = ...
    participants(2).condition_hrfs(1).HbO(:, [2 1]);
participants(2).condition_hrfs(1).HbR = ...
    participants(2).condition_hrfs(1).HbR(:, [2 1]);
verifyError(testCase, @() aggregate_participant_hrfs( ...
    participants, config), ...
    'aggregate_participant_hrfs:IncompatibleChannels');
end

function testDuplicateChannelPairsRejected(testCase)
[participants, config] = valid_inputs(2);
participants(2).condition_hrfs(1).channel_pairs(2, :) = ...
    participants(2).condition_hrfs(1).channel_pairs(1, :);
verifyError(testCase, @() aggregate_participant_hrfs( ...
    participants, config), ...
    'aggregate_participant_hrfs:InvalidParticipants');
end

function testReferenceChannelOrderPreservedExactly(testCase)
[participants, config] = valid_inputs(2);
expected = participants(1).condition_hrfs(1).channel_pairs;
result = aggregate_participant_hrfs(participants, config);
verifyEqual(testCase, result.condition_hrfs(1).channel_pairs, expected);
end

function testEffectiveCountsAndReportsReturned(testCase)
[participants, config] = valid_inputs(6);
for participant_index = 1:6
    participants(participant_index).condition_hrfs(1).HbO(1, 1) = 0;
end
participants(6).condition_hrfs(1).HbO(1, 1) = 10;
result = aggregate_participant_hrfs(participants, config);
verifyEqual(testCase, result.outlier_report(1).HbO.n_included(1, 1), 5);
verifyEqual(testCase, result.outlier_report(1).HbO.n_excluded(1, 1), 1);
verifyEqual(testCase, result.condition_hrfs(1).HbO(1, 1), 0);
end

function testMaskThirdDimensionUsesInputParticipantOrder(testCase)
[participants, config] = valid_inputs(6);
for participant_index = 1:6
    participants(participant_index).condition_hrfs(1).HbO(1, 1) = 0;
end
participants(3).condition_hrfs(1).HbO(1, 1) = 10;
result = aggregate_participant_hrfs(participants, config);
mask = reshape(result.outlier_report(1).HbO.outlier_mask(1, 1, :), 1, []);
verifyEqual(testCase, find(mask), 3);
end

function testParticipantPermutationPreservesMeansAndPermutesMasks(testCase)
[participants, config] = valid_inputs(6);
for participant_index = 1:6
    participants(participant_index).condition_hrfs(1).HbO(1, 1) = 0;
end
participants(3).condition_hrfs(1).HbO(1, 1) = 10;
permutation = [6 3 1 5 2 4];
result_a = aggregate_participant_hrfs(participants, config);
result_b = aggregate_participant_hrfs(participants(permutation), config);
verifyEqual(testCase, result_b.condition_hrfs(1).HbO, ...
    result_a.condition_hrfs(1).HbO);
verifyEqual(testCase, result_b.condition_hrfs(1).HbR, ...
    result_a.condition_hrfs(1).HbR);
verifyEqual(testCase, result_b.outlier_report(1).HbO.outlier_mask, ...
    result_a.outlier_report(1).HbO.outlier_mask(:, :, permutation));
end

function testThresholdForwardedFromConfig(testCase)
[participants, config] = valid_inputs(4);
values = [2 0 0 0];
for participant_index = 1:4
    participants(participant_index).condition_hrfs(1).HbO(1, 1) = ...
        values(participant_index);
end
config.outlier_threshold_sd = 1.5;
result = aggregate_participant_hrfs(participants, config);
verifyEqual(testCase, result.outlier_report(1).HbO.threshold_sd, 1.5);
verifyFalse(testCase, any( ...
    result.outlier_report(1).HbO.outlier_mask(1, 1, :), 'all'));
end

function testParticipantInputsRemainUnchanged(testCase)
[participants, config] = valid_inputs(6);
saved = participants;
aggregate_participant_hrfs(participants, config);
verifyEqual(testCase, participants, saved);
end

function testGroupConfigRemainsUnchanged(testCase)
[participants, config] = valid_inputs(2);
saved = config;
aggregate_participant_hrfs(participants, config);
verifyEqual(testCase, config, saved);
end

function testAdditionalParticipantMetadataIsIgnored(testCase)
[participants, config] = valid_inputs(2);
participants(1).participant_id = 'P01';
participants(2).participant_id = 'P02';
result = aggregate_participant_hrfs(participants, config);
verifyFalse(testCase, isfield(result, 'participant_id'));
verifyFalse(testCase, any(strcmp(fieldnames(result.aggregation), ...
    'participant_ids')));
end

function [participants, config] = valid_inputs(participant_count)
condition_template = struct('name', '', 'time', [], 'HbO', [], ...
    'HbR', [], 'channel_pairs', []);
participant_template = struct('condition_hrfs', ...
    repmat(condition_template, 2, 1));
participants = repmat(participant_template, participant_count, 1);
time = [-1; 0; 1];
channel_pairs = [2 1; 1 3];
for participant_index = 1:participant_count
    a_hbo = participant_index + reshape(1:6, [3 2]);
    a_hbr = -participant_index + reshape(11:16, [3 2]);
    b_hbo = 20 + participant_index + reshape(1:6, [3 2]);
    b_hbr = 30 - participant_index + reshape(1:6, [3 2]);
    participants(participant_index).condition_hrfs(1) = ...
        make_hrf('A', time, a_hbo, a_hbr, channel_pairs);
    participants(participant_index).condition_hrfs(2) = ...
        make_hrf('B', time, b_hbo, b_hbr, channel_pairs);
end
config = struct('input_level', 'participant_condition_hrf', ...
    'initial_statistics', {{'pointwise_mean', 'pointwise_sd'}}, ...
    'outlier_threshold_sd', 2, ...
    'outlier_rule', 'exclude_values_strictly_greater_than_threshold', ...
    'imputation', 'none', ...
    'recalculate_statistics_after_exclusion', true);
end

function hrf = make_hrf(name, time, hbo, hbr, channel_pairs)
hrf = struct('name', name, 'time', time, 'HbO', hbo, 'HbR', hbr, ...
    'channel_pairs', channel_pairs);
end

function values = stack_chromophore(participants, condition_name, field_name)
participant_count = numel(participants);
first_names = {participants(1).condition_hrfs.name};
first_index = find(strcmp(first_names, condition_name), 1);
prototype = participants(1).condition_hrfs(first_index).(field_name);
values = zeros(size(prototype, 1), size(prototype, 2), participant_count);
for participant_index = 1:participant_count
    names = {participants(participant_index).condition_hrfs.name};
    condition_index = find(strcmp(names, condition_name), 1);
    values(:, :, participant_index) = ...
        participants(participant_index).condition_hrfs(condition_index).(field_name);
end
end

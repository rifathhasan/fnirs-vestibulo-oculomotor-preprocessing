function tests = test_pointwise_group_average
%TEST_POINTWISE_GROUP_AVERAGE Synthetic pointwise group tests.
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

function testValidOutputDimensions(testCase)
values = reshape(1:24, [2 3 4]);
[group_mean, report] = pointwise_group_average(values, 10);
verifySize(testCase, group_mean, [2 3]);
verifySize(testCase, report.initial_mean, [2 3]);
verifySize(testCase, report.initial_sd, [2 3]);
verifySize(testCase, report.final_sd, [2 3]);
verifySize(testCase, report.outlier_mask, [2 3 4]);
verifySize(testCase, report.n_included, [2 3]);
verifySize(testCase, report.n_excluded, [2 3]);
end

function testTooFewInputsRejected(testCase)
verifyError(testCase, @() pointwise_group_average(zeros(1, 1, 2)), ...
    'pointwise_group_average:InvalidInputCount');
end

function testTooManyInputsUseMatlabDispatchError(testCase)
verifyError(testCase, @() pointwise_group_average( ...
    zeros(1, 1, 2), 2, true), 'MATLAB:TooManyInputs');
end

function testMalformedValuesRejected(testCase)
invalid = {[], 'values', ones(1, 1, 2) + 1i, ...
    ones(1, 1, 2, 2)};
for index = 1:numel(invalid)
    verifyError(testCase, @() pointwise_group_average(invalid{index}, 2), ...
        'pointwise_group_average:InvalidValues');
end
end

function testNanRejected(testCase)
values = zeros(1, 1, 2);
values(1) = NaN;
verifyError(testCase, @() pointwise_group_average(values, 2), ...
    'pointwise_group_average:InvalidValues');
end

function testInfRejected(testCase)
values = zeros(1, 1, 2);
values(1) = Inf;
verifyError(testCase, @() pointwise_group_average(values, 2), ...
    'pointwise_group_average:InvalidValues');
end

function testTwoDimensionalValuesRepresentOneParticipant(testCase)
verifyError(testCase, @() pointwise_group_average(ones(3, 2), 2), ...
    'pointwise_group_average:InsufficientParticipants');
end

function testInvalidThresholdsRejected(testCase)
invalid = {[], [1 2], 0, -1, NaN, Inf, 1i, '2'};
values = zeros(1, 1, 2);
for index = 1:numel(invalid)
    verifyError(testCase, @() pointwise_group_average( ...
        values, invalid{index}), 'pointwise_group_average:InvalidThreshold');
end
end

function testNoOutlierUsesArithmeticMean(testCase)
values = reshape([1 2 3 4], [1 1 4]);
[group_mean, report] = pointwise_group_average(values, 10);
verifyEqual(testCase, group_mean, 2.5);
verifyFalse(testCase, any(report.outlier_mask(:)));
end

function testClearThresholdTwoOutlierWithSixParticipants(testCase)
values = reshape([0 0 0 0 0 10], [1 1 6]);
[group_mean, report] = pointwise_group_average(values, 2);
verifyEqual(testCase, reshape(report.outlier_mask, 1, []), ...
    logical([0 0 0 0 0 1]));
verifyEqual(testCase, group_mean, 0);
end

function testStrictEqualityBoundaryIsRetained(testCase)
values = reshape([2 0 0 0], [1 1 4]);
[group_mean, report] = pointwise_group_average(values, 1.5);
verifyFalse(testCase, any(report.outlier_mask(:)));
verifyEqual(testCase, group_mean, 0.5);
end

function testSampleSdNotPopulationSd(testCase)
values = reshape([2 0 0 0], [1 1 4]);
[~, report] = pointwise_group_average(values, 1.6);
verifyEqual(testCase, report.initial_sd, 1, 'AbsTol', 1e-15);
verifyFalse(testCase, any(report.outlier_mask(:)));
end

function testCandidateIncludedInInitialStatistics(testCase)
values = reshape([0 0 0 0 0 10], [1 1 6]);
[~, report] = pointwise_group_average(values, 2);
verifyEqual(testCase, report.initial_mean, 10 / 6, 'AbsTol', 1e-15);
verifyEqual(testCase, report.initial_sd, std([0 0 0 0 0 10], 0), ...
    'AbsTol', 1e-15);
end

function testDetectionIsOnePassNotIterative(testCase)
values = reshape([0 0 0 0 0 1 3], [1 1 7]);
[group_mean, report] = pointwise_group_average(values, 2);
verifyEqual(testCase, reshape(report.outlier_mask, 1, []), ...
    logical([0 0 0 0 0 0 1]));
verifyEqual(testCase, group_mean, 1 / 6, 'AbsTol', 1e-15);
end

function testOutlierAtOneTimeIsPointwise(testCase)
values = zeros(2, 1, 6);
values(1, 1, 6) = 10;
values(2, 1, 5:6) = 1;
[group_mean, report] = pointwise_group_average(values, 2);
verifyTrue(testCase, report.outlier_mask(1, 1, 6));
verifyFalse(testCase, report.outlier_mask(2, 1, 6));
verifyFalse(testCase, any(report.outlier_mask(2, 1, :), 'all'));
verifyEqual(testCase, group_mean(1), 0);
verifyEqual(testCase, group_mean(2), 1 / 3, 'AbsTol', 1e-15);
end

function testOutlierAtOneChannelIsPointwise(testCase)
values = zeros(1, 2, 6);
values(1, 1, 6) = 10;
values(1, 2, 5:6) = 1;
[group_mean, report] = pointwise_group_average(values, 2);
verifyTrue(testCase, report.outlier_mask(1, 1, 6));
verifyFalse(testCase, report.outlier_mask(1, 2, 6));
verifyFalse(testCase, any(report.outlier_mask(1, 2, :), 'all'));
verifyEqual(testCase, group_mean(1, 1), 0);
verifyEqual(testCase, group_mean(1, 2), 1 / 3, 'AbsTol', 1e-15);
end

function testZeroSdRetainsIdenticalValues(testCase)
values = 7 * ones(2, 2, 3);
[group_mean, report] = pointwise_group_average(values, 2);
verifyEqual(testCase, report.initial_sd, zeros(2, 2));
verifyFalse(testCase, any(report.outlier_mask(:)));
verifyEqual(testCase, group_mean, 7 * ones(2, 2));
verifyEqual(testCase, report.final_sd, zeros(2, 2));
end

function testInitialStatisticsAreExact(testCase)
values = reshape(1:12, [2 2 3]);
[~, report] = pointwise_group_average(values, 20);
verifyEqual(testCase, report.initial_mean, mean(values, 3));
verifyEqual(testCase, report.initial_sd, std(values, 0, 3));
end

function testFinalSdRecalculatedAfterExclusion(testCase)
values = reshape([0 0 0 0 0 10], [1 1 6]);
[~, report] = pointwise_group_average(values, 2);
verifyEqual(testCase, report.final_sd, 0);
verifyNotEqual(testCase, report.final_sd, report.initial_sd);
end

function testFinalSdIsZeroForOneIncludedValue(testCase)
values = reshape([0 1 2], [1 1 3]);
[group_mean, report] = pointwise_group_average(values, 0.1);
verifyEqual(testCase, report.n_included, 1);
verifyEqual(testCase, group_mean, 1);
verifyEqual(testCase, report.final_sd, 0);
end

function testNoIncludedValuesProduceNanStatistics(testCase)
values = reshape([0 1], [1 1 2]);
[group_mean, report] = pointwise_group_average(values, 0.1);
verifyEqual(testCase, report.n_included, 0);
verifyTrue(testCase, isnan(group_mean));
verifyTrue(testCase, isnan(report.final_sd));
end

function testEffectiveCountsArePointwise(testCase)
values = zeros(2, 1, 6);
values(1, 1, 6) = 10;
[~, report] = pointwise_group_average(values, 2);
verifyEqual(testCase, report.n_included, [5; 6]);
verifyEqual(testCase, report.n_excluded, [1; 0]);
end

function testMaskPreservesParticipantAlignment(testCase)
values = reshape([0 0 10 0 0 0], [1 1 6]);
[~, report] = pointwise_group_average(values, 2);
verifyEqual(testCase, find(reshape(report.outlier_mask, 1, [])), 3);
end

function testReportContainsOnlyApprovedFields(testCase)
[~, report] = pointwise_group_average(zeros(1, 1, 2), 2);
verifyEqual(testCase, fieldnames(report), {'threshold_sd'; 'initial_mean'; ...
    'initial_sd'; 'final_sd'; 'outlier_mask'; 'n_included'; 'n_excluded'});
end

function testInputValuesRemainUnchanged(testCase)
values = reshape([0 0 0 0 0 10], [1 1 6]);
saved = values;
pointwise_group_average(values, 2);
verifyEqual(testCase, values, saved);
end

function testParticipantPermutationPreservesStatisticsAndPermutesMask(testCase)
values = reshape([0 0 10 0 0 0], [1 1 6]);
permutation = [6 3 1 5 2 4];
[mean_a, report_a] = pointwise_group_average(values, 2);
[mean_b, report_b] = pointwise_group_average(values(:, :, permutation), 2);
verifyEqual(testCase, mean_b, mean_a);
verifyEqual(testCase, report_b.initial_mean, report_a.initial_mean);
verifyEqual(testCase, report_b.initial_sd, report_a.initial_sd);
verifyEqual(testCase, report_b.final_sd, report_a.final_sd);
verifyEqual(testCase, report_b.outlier_mask, ...
    report_a.outlier_mask(:, :, permutation));
end

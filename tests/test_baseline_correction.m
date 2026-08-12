function tests = test_baseline_correction
%TEST_BASELINE_CORRECTION Synthetic tests for baseline_correct_hrf.
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

function testKnownChannelOffsetIsRemoved(testCase)
time = (-2:2).';
hrf = [10; 10; 10; 13; 15];
expected = [0; 0; 0; 3; 5];

actual = baseline_correct_hrf(hrf, time, [-2 0]);

verifyEqual(testCase, actual, expected, 'AbsTol', 1e-12);
end

function testMultipleChannelsAreCorrectedIndependently(testCase)
time = (-2:1).';
hrf = [10 -4; 11 -2; 12 0; 15 5];
expected = [-1 -2; 0 0; 1 2; 4 7];

actual = baseline_correct_hrf(hrf, time, [-2 0]);

verifyEqual(testCase, actual, expected, 'AbsTol', 1e-12);
end

function testOutputDimensionsEqualInputDimensions(testCase)
time = -2:2;
hrf = reshape(1:15, 5, 3);

actual = baseline_correct_hrf(hrf, time, [-2 0]);

verifySize(testCase, actual, size(hrf));
end

function testCorrectedBaselineMeanIsApproximatelyZero(testCase)
time = (-3:2).';
hrf = [2 10; 4 14; 8 18; 10 22; 15 31; 20 40];
baseline_window = [-3 0];
baseline_mask = time >= baseline_window(1) & time <= baseline_window(2);

actual = baseline_correct_hrf(hrf, time, baseline_window);

verifyEqual(testCase, mean(actual(baseline_mask, :), 1), [0 0], ...
    'AbsTol', 1e-12);
end

function testNaNsAreOmittedAndPreserved(testCase)
time = (-3:1).';
hrf = [1 NaN; NaN 4; 3 6; 5 8; 9 12];
expected = [-2 NaN; NaN -2; 0 0; 2 2; 6 6];

actual = baseline_correct_hrf(hrf, time, [-3 0]);

verifyEqual(testCase, isnan(actual), isnan(hrf));
verifyEqual(testCase, actual(~isnan(expected)), expected(~isnan(expected)), ...
    'AbsTol', 1e-12);
end

function testOneUsableBaselineSampleRaisesError(testCase)
time = (-2:1).';
hrf = [NaN 2; NaN 4; 3 6; 5 8];

verifyError(testCase, @() baseline_correct_hrf(hrf, time, [-2 0]), ...
    'baseline_correct_hrf:InsufficientValidBaselineSamples');
end

function testInvalidBaselineWindowsRaiseErrors(testCase)
time = (-2:2).';
hrf = (1:5).';

verifyError(testCase, @() baseline_correct_hrf(hrf, time, 0), ...
    'baseline_correct_hrf:InvalidBaselineWindow');
verifyError(testCase, @() baseline_correct_hrf(hrf, time, [0 -1]), ...
    'baseline_correct_hrf:InvalidBaselineWindow');
verifyError(testCase, @() baseline_correct_hrf(hrf, time, [-0.1 0.1]), ...
    'baseline_correct_hrf:InsufficientBaselineSamples');
end

function testInvalidTimeValuesRaiseErrors(testCase)
hrf = (1:4).';

verifyError(testCase, @() baseline_correct_hrf(hrf, [-2 -1 -1 0], [-2 0]), ...
    'baseline_correct_hrf:NonIncreasingTime');
verifyError(testCase, @() baseline_correct_hrf(hrf, [-2 0 -1 1], [-2 0]), ...
    'baseline_correct_hrf:NonIncreasingTime');
verifyError(testCase, @() baseline_correct_hrf(hrf, [-2 -1 NaN 1], [-2 0]), ...
    'baseline_correct_hrf:InvalidTime');
verifyError(testCase, @() baseline_correct_hrf(hrf, [-2 -1 0 Inf], [-2 0]), ...
    'baseline_correct_hrf:InvalidTime');
end

function testPartiallyCoveredBaselineWindowRaisesError(testCase)
time = (-2:2).';
hrf = (1:5).';

verifyError(testCase, @() baseline_correct_hrf(hrf, time, [-3 0]), ...
    'baseline_correct_hrf:IncompleteBaselineCoverage');
verifyError(testCase, @() baseline_correct_hrf(hrf, time, [0 3]), ...
    'baseline_correct_hrf:IncompleteBaselineCoverage');
end

function testTimeAndHrfDimensionMismatchRaisesError(testCase)
time = (-2:2).';
hrf = ones(4, 2);

verifyError(testCase, @() baseline_correct_hrf(hrf, time, [-2 0]), ...
    'baseline_correct_hrf:TimeDimensionMismatch');
end

function testValuesChangeOnlyByChannelBaselineSubtraction(testCase)
time = (-2:2).';
hrf = [2 20; 4 25; 9 30; 15 45; 21 60];
baseline_means = [5 25];
expected = bsxfun(@minus, hrf, baseline_means);

actual = baseline_correct_hrf(hrf, time, [-2 0]);

verifyEqual(testCase, actual, expected, 'AbsTol', 1e-12);
verifyEqual(testCase, hrf - actual, repmat(baseline_means, size(hrf, 1), 1), ...
    'AbsTol', 1e-12);
end

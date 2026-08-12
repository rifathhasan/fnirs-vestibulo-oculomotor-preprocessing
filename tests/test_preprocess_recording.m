function tests = test_preprocess_recording
%TEST_PREPROCESS_RECORDING Synthetic Stage D orchestration tests.
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

function setup(~)
global PREPROCESS_RECORDING_SPY_STATE
PREPROCESS_RECORDING_SPY_STATE = struct('call_order', {cell(0, 1)}, ...
    'bandpass_call_count', 0);
end

function teardown(~)
global PREPROCESS_RECORDING_SPY_STATE
PREPROCESS_RECORDING_SPY_STATE = [];
clear global PREPROCESS_RECORDING_SPY_STATE
end

function testValidSyntheticPipelineReturnsApprovedResult(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
result = call_preprocess(recording, validation, conditions, config, operators);
verifySize(testCase, result.condition_hrfs, [1 1]);
verifyEqual(testCase, result.condition_hrfs.name, 'COND');
verifyTrue(testCase, result.epoch_report(1).included_trial_count > 0);
end

function testResultContainsExactlyApprovedTopLevelFields(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
result = call_preprocess(recording, validation, conditions, config, operators);
verifyEqual(testCase, fieldnames(result), ...
    {'condition_hrfs'; 'block_hrfs'; 'epoch_report'; 'preprocessing'});
end

function testConditionHrfsContainOnlyApprovedFields(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
result = call_preprocess(recording, validation, conditions, config, operators);
verifyEqual(testCase, fieldnames(result.condition_hrfs), ...
    {'name'; 'time'; 'HbO'; 'HbR'; 'channel_pairs'});
end

function testBlockHrfsContainOnlyApprovedFields(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
result = call_preprocess(recording, validation, conditions, config, operators);
verifyEqual(testCase, fieldnames(result.block_hrfs), ...
    {'name'; 'time'; 'HbO'; 'HbR'; 'channel_pairs'; 'block_indices'});
end

function testPreprocessingContainsOnlyApprovedFields(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
result = call_preprocess(recording, validation, conditions, config, operators);
verifyEqual(testCase, fieldnames(result.preprocessing), ...
    {'wavelet_iqr'; 'bandpass_hz'; 'dpf'; ...
     'measured_sampling_rate_hz'; 'median_sampling_interval_s'; ...
     'block_average_window_s'; 'baseline_window_s'});
end

function testTooFewInputsRejected(testCase)
[recording, validation, conditions, config, ~] = valid_inputs();
verifyError(testCase, @() preprocess_recording( ...
    recording, validation, conditions, config), ...
    'preprocess_recording:InvalidInputCount');
end

function testTooManyInputsUseMatlabDispatchError(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
verifyError(testCase, @() preprocess_recording( ...
    recording, validation, conditions, config, operators, true), ...
    'MATLAB:TooManyInputs');
end

function testMalformedRecordingRejectedBeforeOperators(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
invalid = {struct(), recording, recording, recording};
invalid{2}.data_representation = 'optical_density';
invalid{3}.intensity(1) = 0;
invalid{4}.time(3) = invalid{4}.time(2);
for index = 1:numel(invalid)
    reset_spy_calls();
    verifyError(testCase, @() call_preprocess(invalid{index}, validation, ...
        conditions, config, operators), 'preprocess_recording:InvalidRecording');
    verifyNoOperatorCalls(testCase);
end
end

function testMalformedValidationRejectedBeforeOperators(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
invalid = {struct(), validation, validation, validation};
invalid{2}.is_structurally_valid = false;
invalid{3}.wavelength_count_matches_expected = false;
invalid{4}.qc_failures = [];
for index = 1:numel(invalid)
    reset_spy_calls();
    verifyError(testCase, @() call_preprocess(recording, invalid{index}, ...
        conditions, config, operators), ...
        'preprocess_recording:InvalidValidation');
    verifyNoOperatorCalls(testCase);
end
end

function testSampleCountMismatchRejectedBeforeOperators(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
validation.time_sample_count = validation.time_sample_count + 1;
verifyError(testCase, @() call_preprocess(recording, validation, ...
    conditions, config, operators), 'preprocess_recording:InvalidValidation');
verifyNoOperatorCalls(testCase);
end

function testMeasurementCountMismatchRejectedBeforeOperators(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
validation.measurement_count = validation.measurement_count + 1;
verifyError(testCase, @() call_preprocess(recording, validation, ...
    conditions, config, operators), 'preprocess_recording:InvalidValidation');
verifyNoOperatorCalls(testCase);
end

function testMedianIntervalMismatchRejectedBeforeOperators(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
validation.median_sampling_interval_s = 1.25;
validation.measured_sampling_rate_hz = 0.8;
verifyError(testCase, @() call_preprocess(recording, validation, ...
    conditions, config, operators), 'preprocess_recording:InvalidValidation');
verifyNoOperatorCalls(testCase);
end

function testReciprocalRateMismatchRejectedBeforeOperators(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
validation.measured_sampling_rate_hz = 1.25;
verifyError(testCase, @() call_preprocess(recording, validation, ...
    conditions, config, operators), 'preprocess_recording:InvalidValidation');
verifyNoOperatorCalls(testCase);
end

function testInconsistentQcAggregateRejectedBeforeOperators(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
validation.all_acquisition_expectations_met = false;
verifyError(testCase, @() call_preprocess(recording, validation, ...
    conditions, config, operators), 'preprocess_recording:InvalidValidation');
verifyNoOperatorCalls(testCase);
end

function testAcquisitionQcFailurePreventsEveryOperatorCall(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
validation.sampling_rate_within_tolerance = false;
validation.all_acquisition_expectations_met = false;
validation.qc_failures = make_qc_failure('sampling_rate');
verifyError(testCase, @() call_preprocess(recording, validation, ...
    conditions, config, operators), ...
    'preprocess_recording:AcquisitionQcFailed');
verifyNoOperatorCalls(testCase);
end

function testMalformedConfigRejectedBeforeOperators(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
invalid = {struct(), config, config, config, config};
invalid{2}.motion_correction.iqr = -1;
invalid{3}.filter.passband_hz = [0.4 0.2];
invalid{4}.concentration_conversion.dpf = [2; 3];
invalid{5}.baseline_window_s = [-3 0];
for index = 1:numel(invalid)
    reset_spy_calls();
    verifyError(testCase, @() call_preprocess(recording, validation, ...
        conditions, invalid{index}, operators), ...
        'preprocess_recording:InvalidConfig');
    verifyNoOperatorCalls(testCase);
end
end

function testNoncanonicalMethodDeclarationsRejected(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
invalid = {config, config, config, config, config};
invalid{1}.input_representation = 'optical_density';
invalid{2}.motion_correction.method = 'spline';
invalid{3}.filter.type = 'lowpass';
invalid{4}.filter.application_count = 2;
invalid{5}.chromophores = {'HbR', 'HbO'};
for index = 1:numel(invalid)
    reset_spy_calls();
    verifyError(testCase, @() call_preprocess(recording, validation, ...
        conditions, invalid{index}, operators), ...
        'preprocess_recording:InvalidConfig');
    verifyNoOperatorCalls(testCase);
end
end

function testMissingOperatorRejectedBeforeCalls(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
operators = rmfield(operators, 'bandpass_od');
verifyError(testCase, @() call_preprocess(recording, validation, ...
    conditions, config, operators), 'preprocess_recording:InvalidOperators');
verifyNoOperatorCalls(testCase);
end

function testNonFunctionOperatorRejectedBeforeCalls(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
operators.od_to_concentration = 42;
verifyError(testCase, @() call_preprocess(recording, validation, ...
    conditions, config, operators), 'preprocess_recording:InvalidOperators');
verifyNoOperatorCalls(testCase);
end

function testVararginOperatorHandlesAreAccepted(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
operators.intensity_to_od = @(varargin) spy_intensity_to_od(varargin{:});
result = call_preprocess(recording, validation, conditions, config, operators);
verifyEqual(testCase, result.condition_hrfs.name, 'COND');
end

function testMalformedTopLevelConditionsRejectedBeforeOperators(testCase)
[recording, validation, ~, config, operators] = valid_inputs();
invalid = {struct(), [], struct('COND', 7)};
for index = 1:numel(invalid)
    reset_spy_calls();
    verifyError(testCase, @() call_preprocess(recording, validation, ...
        invalid{index}, config, operators), ...
        'preprocess_recording:InvalidConditions');
    verifyNoOperatorCalls(testCase);
end
end

function testExactOperatorCallOrder(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
call_preprocess(recording, validation, conditions, config, operators);
global PREPROCESS_RECORDING_SPY_STATE
verifyEqual(testCase, PREPROCESS_RECORDING_SPY_STATE.call_order, ...
    {'intensity_to_od'; 'wavelet_correct_od'; ...
     'bandpass_od'; 'od_to_concentration'});
end

function testBandpassCalledExactlyOnce(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
call_preprocess(recording, validation, conditions, config, operators);
global PREPROCESS_RECORDING_SPY_STATE
verifyEqual(testCase, PREPROCESS_RECORDING_SPY_STATE.bandpass_call_count, 1);
end

function testRawIntensityForwardedUnchanged(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
call_preprocess(recording, validation, conditions, config, operators);
global PREPROCESS_RECORDING_SPY_STATE
verifyTrue(testCase, isequaln( ...
    PREPROCESS_RECORDING_SPY_STATE.intensity_argument, recording.intensity));
end

function testWaveletIqrForwardedFromConfig(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
config.motion_correction.iqr = 0.73;
call_preprocess(recording, validation, conditions, config, operators);
global PREPROCESS_RECORDING_SPY_STATE
verifyEqual(testCase, PREPROCESS_RECORDING_SPY_STATE.wavelet_iqr, 0.73);
end

function testBandpassArgumentsForwardedFromInputs(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
config.filter.passband_hz = [0.17 0.31];
call_preprocess(recording, validation, conditions, config, operators);
global PREPROCESS_RECORDING_SPY_STATE
verifyEqual(testCase, PREPROCESS_RECORDING_SPY_STATE.bandpass_rate, ...
    validation.measured_sampling_rate_hz);
verifyEqual(testCase, PREPROCESS_RECORDING_SPY_STATE.bandpass_low, 0.17);
verifyEqual(testCase, PREPROCESS_RECORDING_SPY_STATE.bandpass_high, 0.31);
end

function testDpfForwardedUnchanged(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
config.concentration_conversion.dpf = [2.3 4.7];
call_preprocess(recording, validation, conditions, config, operators);
global PREPROCESS_RECORDING_SPY_STATE
verifyTrue(testCase, isequaln( ...
    PREPROCESS_RECORDING_SPY_STATE.mbll_dpf, [2.3 4.7]));
end

function testEachOperatorReceivesPreviousStageOutput(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
call_preprocess(recording, validation, conditions, config, operators);
global PREPROCESS_RECORDING_SPY_STATE
state = PREPROCESS_RECORDING_SPY_STATE;
verifyTrue(testCase, isequaln(state.wavelet_od, state.od_output));
verifyTrue(testCase, isequaln(state.bandpass_od_argument, ...
    state.corrected_od_output));
verifyTrue(testCase, isequaln(state.mbll_od, state.filtered_od_output));
end

function testSameChannelSetInSameOrderAccepted(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
result = call_preprocess(recording, validation, conditions, config, operators);
verifyEqual(testCase, result.condition_hrfs.channel_pairs, ...
    validation.channel_pairs);
end

function testDifferentValidChannelOrderingAccepted(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
validation.channel_pairs = flipud(validation.channel_pairs);
result = call_preprocess(recording, validation, conditions, config, operators);
global PREPROCESS_RECORDING_SPY_STATE
verifyEqual(testCase, result.condition_hrfs.channel_pairs, ...
    PREPROCESS_RECORDING_SPY_STATE.concentration_output.channel_pairs);
end

function testFinalChannelOrderRemainsMbllOrder(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
validation.channel_pairs = flipud(validation.channel_pairs);
result = call_preprocess(recording, validation, conditions, config, operators);
verifyEqual(testCase, result.condition_hrfs.channel_pairs, [1 1; 2 1]);
verifyEqual(testCase, result.condition_hrfs.HbO(:, 1), ...
    baseline_correct_hrf((13:17).', (-2:2).', [-2 0]));
end

function testGenuineChannelSetMismatchRejected(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
validation.channel_pairs = [1 1; 3 1];
verifyError(testCase, @() call_preprocess(recording, validation, ...
    conditions, config, operators), 'preprocess_recording:InvalidValidation');
end

function testDuplicateValidationChannelMetadataRejectedBeforeOperators(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
validation.channel_pairs = [1 1; 1 1];
verifyError(testCase, @() call_preprocess(recording, validation, ...
    conditions, config, operators), 'preprocess_recording:InvalidValidation');
verifyNoOperatorCalls(testCase);
end

function testDuplicateConcentrationChannelMetadataRejected(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
global PREPROCESS_RECORDING_SPY_STATE
PREPROCESS_RECORDING_SPY_STATE.concentration_output.channel_pairs = ...
    [1 1; 1 1];
verifyError(testCase, @() call_preprocess(recording, validation, ...
    conditions, config, operators), 'preprocess_recording:InvalidValidation');
end

function testBlockAverageWindowFromConfigControlsOutput(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
config.block_average_window_s = [-1 1];
config.baseline_window_s = [-1 0];
result = call_preprocess(recording, validation, conditions, config, operators);
verifyEqual(testCase, result.condition_hrfs.time, (-1:1).');
verifySize(testCase, result.condition_hrfs.HbO, [3 2]);
end

function testMedianSamplingIntervalControlsEpochGrid(testCase)
[recording, validation, conditions, config, operators] = ...
    half_second_inputs();
result = call_preprocess(recording, validation, conditions, config, operators);
verifyEqual(testCase, result.condition_hrfs.time, (-2:2).' * 0.5);
end

function testFiveCompleteBlocksAreExposedWithExpectedDimensions(testCase)
[recording, validation, conditions, config, operators] = five_block_inputs();
result = call_preprocess(recording, validation, conditions, config, operators);
verifySize(testCase, result.block_hrfs, [1 1]);
verifyEqual(testCase, result.block_hrfs.name, 'COND');
verifyEqual(testCase, size(result.block_hrfs.HbO, 1), 5);
verifyEqual(testCase, size(result.block_hrfs.HbO, 2), 2);
verifyEqual(testCase, size(result.block_hrfs.HbO, 3), 5);
verifyEqual(testCase, size(result.block_hrfs.HbR, 1), 5);
verifyEqual(testCase, size(result.block_hrfs.HbR, 2), 2);
verifyEqual(testCase, size(result.block_hrfs.HbR, 3), 5);
end

function testCompleteBlockOrderAndOriginalOrdinalsArePreserved(testCase)
[recording, validation, conditions, config, operators] = five_block_inputs();
global PREPROCESS_RECORDING_SPY_STATE
[~, ~, raw_blocks] = epoch_and_average_conditions( ...
    PREPROCESS_RECORDING_SPY_STATE.concentration_output, recording.time, ...
    conditions, config.block_average_window_s, ...
    validation.median_sampling_interval_s);
result = call_preprocess(recording, validation, conditions, config, operators);
verifyEqual(testCase, result.block_hrfs.block_indices, 1:5);
for block_index = 1:5
    expected = baseline_correct_hrf( ...
        raw_blocks.HbO(:, :, block_index), raw_blocks.time, ...
        config.baseline_window_s);
    verifyEqual(testCase, result.block_hrfs.HbO(:, :, block_index), expected);
end
end

function testBoundaryExcludedBlocksAreAbsentAndOrdinalsPreserved(testCase)
[recording, validation, ~, config, operators] = five_block_inputs();
conditions = make_conditions('COND', [1 5 10 15 29], 5);
result = call_preprocess(recording, validation, conditions, config, operators);
verifyEqual(testCase, size(result.block_hrfs.HbO, 3), 3);
verifyEqual(testCase, size(result.block_hrfs.HbR, 3), 3);
verifyEqual(testCase, result.block_hrfs.block_indices, [2 3 4]);
verifyEqual(testCase, result.epoch_report.included_trial_count, 3);
verifyEqual(testCase, result.epoch_report.excluded_trial_count, 2);
end

function testIndividualHbOAndHbRBlocksAreBaselineCorrected(testCase)
[recording, validation, conditions, config, operators] = five_block_inputs();
global PREPROCESS_RECORDING_SPY_STATE
[~, ~, raw_blocks] = epoch_and_average_conditions( ...
    PREPROCESS_RECORDING_SPY_STATE.concentration_output, recording.time, ...
    conditions, config.block_average_window_s, ...
    validation.median_sampling_interval_s);
result = call_preprocess(recording, validation, conditions, config, operators);
for block_index = 1:5
    expected_hbo = baseline_correct_hrf( ...
        raw_blocks.HbO(:, :, block_index), raw_blocks.time, ...
        config.baseline_window_s);
    expected_hbr = baseline_correct_hrf( ...
        raw_blocks.HbR(:, :, block_index), raw_blocks.time, ...
        config.baseline_window_s);
    verifyEqual(testCase, result.block_hrfs.HbO(:, :, block_index), ...
        expected_hbo);
    verifyEqual(testCase, result.block_hrfs.HbR(:, :, block_index), ...
        expected_hbr);
end
end

function testBlockMetadataAndMeanInvariantArePreserved(testCase)
[recording, validation, conditions, config, operators] = five_block_inputs();
result = call_preprocess(recording, validation, conditions, config, operators);
verifyTrue(testCase, iscolumn(result.block_hrfs.time));
verifyEqual(testCase, result.block_hrfs.time, result.condition_hrfs.time);
verifyEqual(testCase, result.block_hrfs.channel_pairs, [1 1; 2 1]);
verifyEqual(testCase, mean(result.block_hrfs.HbO, 3), ...
    result.condition_hrfs.HbO, 'AbsTol', 1e-12);
verifyEqual(testCase, mean(result.block_hrfs.HbR, 3), ...
    result.condition_hrfs.HbR, 'AbsTol', 1e-12);
verifyFalse(testCase, any(ismember(fieldnames(result.block_hrfs), ...
    {'participant_id'; 'participant_name'; 'session'})));
end

function testConditionOrderPreserved(testCase)
[recording, validation, ~, config, operators] = valid_inputs();
conditions = struct();
conditions.SECOND = condition_value('SECOND', 5, 1);
conditions.FIRST = condition_value('FIRST', 6, 1);
result = call_preprocess(recording, validation, conditions, config, operators);
verifyEqual(testCase, {result.condition_hrfs.name}.', {'SECOND'; 'FIRST'});
verifyEqual(testCase, {result.epoch_report.name}.', {'SECOND'; 'FIRST'});
end

function testEpochReportPreservedExactly(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
global PREPROCESS_RECORDING_SPY_STATE
concentration = PREPROCESS_RECORDING_SPY_STATE.concentration_output;
[~, expected_report] = epoch_and_average_conditions( ...
    concentration, recording.time, conditions, ...
    config.block_average_window_s, validation.median_sampling_interval_s);
result = call_preprocess(recording, validation, conditions, config, operators);
verifyTrue(testCase, isequaln(result.epoch_report, expected_report));
end

function testDetailedStageCConditionErrorPropagates(testCase)
[recording, validation, ~, config, operators] = valid_inputs();
conditions.BAD = struct('name', 'BAD');
verifyError(testCase, @() call_preprocess(recording, validation, ...
    conditions, config, operators), ...
    'epoch_and_average_conditions:InvalidConditions');
end

function testZeroIncludedTrialsRaisesNoIncludedTrials(testCase)
[recording, validation, ~, config, operators] = valid_inputs();
conditions = make_conditions('COND', 0, 1);
verifyError(testCase, @() call_preprocess(recording, validation, ...
    conditions, config, operators), ...
    'preprocess_recording:NoIncludedTrials');
end

function testFinalHbOEqualsBaselineCorrectionOfStageCAverage(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
global PREPROCESS_RECORDING_SPY_STATE
[averages, ~] = epoch_and_average_conditions( ...
    PREPROCESS_RECORDING_SPY_STATE.concentration_output, recording.time, ...
    conditions, config.block_average_window_s, ...
    validation.median_sampling_interval_s);
expected = baseline_correct_hrf( ...
    averages.HbO, averages.time, config.baseline_window_s);
result = call_preprocess(recording, validation, conditions, config, operators);
verifyEqual(testCase, result.condition_hrfs.HbO, expected);
end

function testFinalHbREqualsBaselineCorrectionOfStageCAverage(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
global PREPROCESS_RECORDING_SPY_STATE
[averages, ~] = epoch_and_average_conditions( ...
    PREPROCESS_RECORDING_SPY_STATE.concentration_output, recording.time, ...
    conditions, config.block_average_window_s, ...
    validation.median_sampling_interval_s);
expected = baseline_correct_hrf( ...
    averages.HbR, averages.time, config.baseline_window_s);
result = call_preprocess(recording, validation, conditions, config, operators);
verifyEqual(testCase, result.condition_hrfs.HbR, expected);
end

function testHbOAndHbRAreCorrectedIndependently(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
result = call_preprocess(recording, validation, conditions, config, operators);
verifyNotEqual(testCase, result.condition_hrfs.HbO, ...
    result.condition_hrfs.HbR);
verifyEqual(testCase, mean(result.condition_hrfs.HbO(1:3, :), 1), [0 0]);
verifyEqual(testCase, mean(result.condition_hrfs.HbR(1:3, :), 1), [0 0]);
end

function testBaselineWindowFromConfigControlsCorrection(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
first = call_preprocess(recording, validation, conditions, config, operators);
config.baseline_window_s = [-1 0];
second = call_preprocess(recording, validation, conditions, config, operators);
verifyNotEqual(testCase, first.condition_hrfs.HbO, second.condition_hrfs.HbO);
verifyEqual(testCase, mean(second.condition_hrfs.HbO(2:3, :), 1), [0 0]);
end

function testNoIntermediateArraysAppearInResult(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
result = call_preprocess(recording, validation, conditions, config, operators);
prohibited = {'od', 'corrected_od', 'filtered_od', 'concentration', ...
    'trials', 'validation_index_for_result'};
verifyFalse(testCase, any(ismember(fieldnames(result), prohibited)));
verifyFalse(testCase, any(ismember(fieldnames(result.preprocessing), prohibited)));
end

function testPreprocessingMetadataRecordsActualValues(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
config.motion_correction.iqr = 0.61;
config.filter.passband_hz = [0.14 0.29];
config.concentration_conversion.dpf = [3.2 4.8];
result = call_preprocess(recording, validation, conditions, config, operators);
expected = struct('wavelet_iqr', 0.61, ...
    'bandpass_hz', [0.14 0.29], 'dpf', [3.2 4.8], ...
    'measured_sampling_rate_hz', validation.measured_sampling_rate_hz, ...
    'median_sampling_interval_s', validation.median_sampling_interval_s, ...
    'block_average_window_s', config.block_average_window_s, ...
    'baseline_window_s', config.baseline_window_s);
verifyTrue(testCase, isequaln(result.preprocessing, expected));
end

function testAllInputsRemainUnchanged(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
saved = {recording, validation, conditions, config, operators};
call_preprocess(recording, validation, conditions, config, operators);
verifyTrue(testCase, isequaln(recording, saved{1}));
verifyTrue(testCase, isequaln(validation, saved{2}));
verifyTrue(testCase, isequaln(conditions, saved{3}));
verifyTrue(testCase, isequaln(config, saved{4}));
verifyTrue(testCase, isequaln(operators, saved{5}));
end

function testInjectedOperatorErrorPropagatesUnchanged(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
global PREPROCESS_RECORDING_SPY_STATE
PREPROCESS_RECORDING_SPY_STATE.wavelet_error = 'synthetic:waveletFailure';
verifyError(testCase, @() call_preprocess(recording, validation, ...
    conditions, config, operators), 'synthetic:waveletFailure');
end

function testBaselineErrorPropagatesUnchanged(testCase)
[recording, validation, conditions, config, operators] = valid_inputs();
config.block_average_window_s = [-1 1];
config.baseline_window_s = [-0.5 0.5];
verifyError(testCase, @() call_preprocess(recording, validation, ...
    conditions, config, operators), ...
    'baseline_correct_hrf:InsufficientBaselineSamples');
end

function [recording, validation, conditions, config, operators] = valid_inputs()
time = (0:10).';
recording = struct('data_representation', 'raw_intensity', ...
    'intensity', reshape(1:44, 11, 4), 'time', time);
validation = valid_validation(recording, [1 1; 2 1], 1);
conditions = make_conditions('COND', 5, 1);
config = valid_config();
operators = spy_operators();

global PREPROCESS_RECORDING_SPY_STATE
PREPROCESS_RECORDING_SPY_STATE.od_output = recording.intensity + 100;
PREPROCESS_RECORDING_SPY_STATE.corrected_od_output = recording.intensity + 200;
PREPROCESS_RECORDING_SPY_STATE.filtered_od_output = recording.intensity + 300;
PREPROCESS_RECORDING_SPY_STATE.concentration_output = struct( ...
    'HbO', [10 + time, 40 + 2 * time], ...
    'HbR', [30 - 2 * time, 70 - 3 * time], ...
    'channel_pairs', [1 1; 2 1]);
end

function [recording, validation, conditions, config, operators] = ...
        half_second_inputs()
[recording, validation, conditions, config, operators] = valid_inputs();
time = (0:0.5:5).';
recording.time = time;
recording.intensity = reshape(1:44, 11, 4);
validation = valid_validation(recording, [1 1; 2 1], 0.5);
conditions = make_conditions('COND', 2.5, 1);
config.block_average_window_s = [-1 1];
config.baseline_window_s = [-1 0];
global PREPROCESS_RECORDING_SPY_STATE
PREPROCESS_RECORDING_SPY_STATE.od_output = recording.intensity + 100;
PREPROCESS_RECORDING_SPY_STATE.corrected_od_output = recording.intensity + 200;
PREPROCESS_RECORDING_SPY_STATE.filtered_od_output = recording.intensity + 300;
PREPROCESS_RECORDING_SPY_STATE.concentration_output = struct( ...
    'HbO', [10 + time, 40 + 2 * time], ...
    'HbR', [30 - 2 * time, 70 - 3 * time], ...
    'channel_pairs', [1 1; 2 1]);
end

function [recording, validation, conditions, config, operators] = ...
        five_block_inputs()
[recording, ~, ~, config, operators] = valid_inputs();
time = (0:30).';
recording.time = time;
recording.intensity = reshape(1:124, 31, 4);
validation = valid_validation(recording, [1 1; 2 1], 1);
conditions = make_conditions('COND', [3 8 13 18 23], 5);
global PREPROCESS_RECORDING_SPY_STATE
PREPROCESS_RECORDING_SPY_STATE.od_output = recording.intensity + 100;
PREPROCESS_RECORDING_SPY_STATE.corrected_od_output = ...
    recording.intensity + 200;
PREPROCESS_RECORDING_SPY_STATE.filtered_od_output = ...
    recording.intensity + 300;
PREPROCESS_RECORDING_SPY_STATE.concentration_output = struct( ...
    'HbO', [100 + time .^ 2, 40 + 3 * time + 0.5 * time .^ 2], ...
    'HbR', [30 - 2 * time + 0.25 * time .^ 2, 70 - time .^ 2], ...
    'channel_pairs', [1 1; 2 1]);
end

function validation = valid_validation(recording, channel_pairs, interval)
failure_template = struct('check', '', 'measured_value', [], ...
    'expected_value', [], 'tolerance', []);
validation = struct( ...
    'is_structurally_valid', true, ...
    'data_representation', 'raw_intensity', ...
    'time_sample_count', numel(recording.time), ...
    'measurement_count', size(recording.intensity, 2), ...
    'median_sampling_interval_s', interval, ...
    'measured_sampling_rate_hz', 1 / interval, ...
    'sampling_rate_within_tolerance', true, ...
    'sampling_intervals_within_tolerance', true, ...
    'channel_count', size(channel_pairs, 1), ...
    'channel_count_matches_expected', true, ...
    'channel_pairs', channel_pairs, ...
    'wavelength_count_matches_expected', true, ...
    'qc_failures', repmat(failure_template, 0, 1), ...
    'all_acquisition_expectations_met', true);
end

function failure = make_qc_failure(check)
failure = struct('check', check, 'measured_value', 1, ...
    'expected_value', 2, 'tolerance', 0);
end

function config = valid_config()
config = struct();
config.input_representation = 'raw_intensity';
config.motion_correction = struct('method', 'wavelet', 'iqr', 0.8);
config.filter = struct('type', 'bandpass', ...
    'passband_hz', [0.2 0.3], 'application_count', 1, ...
    'input_representation', 'motion_corrected_optical_density');
config.concentration_conversion = struct( ...
    'method', 'modified_beer_lambert', 'dpf', [2 3]);
config.chromophores = {'HbO', 'HbR'};
config.block_average_window_s = [-2 2];
config.baseline_window_s = [-2 0];
end

function conditions = make_conditions(name, onsets, expected_count)
conditions = struct();
conditions.(name) = condition_value(name, onsets, expected_count);
end

function condition = condition_value(name, onsets, expected_count)
onsets = onsets(:);
detected_count = numel(onsets);
condition = struct('name', name, 'onsets', onsets, 'durations', [], ...
    'has_durations', false, 'trial_count', detected_count, ...
    'expected_trial_count', expected_count, ...
    'trial_count_matches_expected', detected_count == expected_count);
end

function operators = spy_operators()
operators = struct('intensity_to_od', @spy_intensity_to_od, ...
    'wavelet_correct_od', @spy_wavelet_correct_od, ...
    'bandpass_od', @spy_bandpass_od, ...
    'od_to_concentration', @spy_od_to_concentration);
end

function od = spy_intensity_to_od(intensity)
global PREPROCESS_RECORDING_SPY_STATE
record_spy_call('intensity_to_od');
PREPROCESS_RECORDING_SPY_STATE.intensity_argument = intensity;
raise_spy_error('intensity_error');
od = PREPROCESS_RECORDING_SPY_STATE.od_output;
end

function corrected = spy_wavelet_correct_od(od, iqr)
global PREPROCESS_RECORDING_SPY_STATE
record_spy_call('wavelet_correct_od');
PREPROCESS_RECORDING_SPY_STATE.wavelet_od = od;
PREPROCESS_RECORDING_SPY_STATE.wavelet_iqr = iqr;
raise_spy_error('wavelet_error');
corrected = PREPROCESS_RECORDING_SPY_STATE.corrected_od_output;
end

function filtered = spy_bandpass_od(od, rate, low, high)
global PREPROCESS_RECORDING_SPY_STATE
record_spy_call('bandpass_od');
PREPROCESS_RECORDING_SPY_STATE.bandpass_call_count = ...
    PREPROCESS_RECORDING_SPY_STATE.bandpass_call_count + 1;
PREPROCESS_RECORDING_SPY_STATE.bandpass_od_argument = od;
PREPROCESS_RECORDING_SPY_STATE.bandpass_rate = rate;
PREPROCESS_RECORDING_SPY_STATE.bandpass_low = low;
PREPROCESS_RECORDING_SPY_STATE.bandpass_high = high;
raise_spy_error('bandpass_error');
filtered = PREPROCESS_RECORDING_SPY_STATE.filtered_od_output;
end

function concentration = spy_od_to_concentration(od, dpf)
global PREPROCESS_RECORDING_SPY_STATE
record_spy_call('od_to_concentration');
PREPROCESS_RECORDING_SPY_STATE.mbll_od = od;
PREPROCESS_RECORDING_SPY_STATE.mbll_dpf = dpf;
raise_spy_error('mbll_error');
concentration = PREPROCESS_RECORDING_SPY_STATE.concentration_output;
end

function record_spy_call(name)
global PREPROCESS_RECORDING_SPY_STATE
PREPROCESS_RECORDING_SPY_STATE.call_order{end + 1, 1} = name;
end

function raise_spy_error(field_name)
global PREPROCESS_RECORDING_SPY_STATE
if isfield(PREPROCESS_RECORDING_SPY_STATE, field_name)
    error(PREPROCESS_RECORDING_SPY_STATE.(field_name), ...
        'Synthetic injected operator failure.');
end
end

function reset_spy_calls()
global PREPROCESS_RECORDING_SPY_STATE
PREPROCESS_RECORDING_SPY_STATE.call_order = cell(0, 1);
PREPROCESS_RECORDING_SPY_STATE.bandpass_call_count = 0;
end

function verifyNoOperatorCalls(testCase)
global PREPROCESS_RECORDING_SPY_STATE
verifyEmpty(testCase, PREPROCESS_RECORDING_SPY_STATE.call_order);
verifyEqual(testCase, PREPROCESS_RECORDING_SPY_STATE.bandpass_call_count, 0);
end

function result = call_preprocess( ...
        recording, validation, conditions, config, operators)
result = preprocess_recording( ...
    recording, validation, conditions, config, operators);
end

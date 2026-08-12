function tests = test_validate_raw_recording
%TEST_VALIDATE_RAW_RECORDING Synthetic tests for validate_raw_recording.
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

function testValidThirtyChannelRecordingPasses(testCase)
[recording, requirements] = make_valid_inputs();
report = validate_raw_recording(recording, requirements);
verifyTrue(testCase, report.is_structurally_valid);
verifyEqual(testCase, report.channel_count, 30);
verifyEqual(testCase, report.measurement_count, 60);
verifyTrue(testCase, report.all_acquisition_expectations_met);
verifyEmpty(testCase, report.qc_failures);
end

function testRawIntensityRepresentationAccepted(testCase)
[recording, requirements] = make_valid_inputs();
recording.data_representation = '  RAW_INTENSITY  ';
report = validate_raw_recording(recording, requirements);
verifyEqual(testCase, report.data_representation, 'raw_intensity');
end

function testProcessedRepresentationsRejected(testCase)
[recording, requirements] = make_valid_inputs();
invalid = {'optical_density', 'concentration', 'HbO', 'HbR', 'raw'};
for index = 1:numel(invalid)
    recording.data_representation = invalid{index};
    verifyError(testCase, @() validate_raw_recording(recording, requirements), ...
        'validate_raw_recording:InvalidDataRepresentation');
end
end

function testNaNIntensityRejected(testCase)
[recording, requirements] = make_valid_inputs();
recording.intensity(1) = NaN;
verifyError(testCase, @() validate_raw_recording(recording, requirements), ...
    'validate_raw_recording:InvalidIntensity');
end

function testInfIntensityRejected(testCase)
[recording, requirements] = make_valid_inputs();
recording.intensity(1) = Inf;
verifyError(testCase, @() validate_raw_recording(recording, requirements), ...
    'validate_raw_recording:InvalidIntensity');
end

function testZeroIntensityRejected(testCase)
[recording, requirements] = make_valid_inputs();
recording.intensity(1) = 0;
verifyError(testCase, @() validate_raw_recording(recording, requirements), ...
    'validate_raw_recording:InvalidIntensity');
end

function testNegativeIntensityRejected(testCase)
[recording, requirements] = make_valid_inputs();
recording.intensity(1) = -1;
verifyError(testCase, @() validate_raw_recording(recording, requirements), ...
    'validate_raw_recording:InvalidIntensity');
end

function testOtherInvalidIntensityInputsRejected(testCase)
[recording, requirements] = make_valid_inputs();
invalid = {[], 'invalid', complex(recording.intensity, 1), ...
    reshape(recording.intensity, 3, 2, 60)};
for index = 1:numel(invalid)
    candidate = recording;
    candidate.intensity = invalid{index};
    verifyError(testCase, @() validate_raw_recording(candidate, requirements), ...
        'validate_raw_recording:InvalidIntensity');
end
end

function testTimeIntensityLengthMismatchRejected(testCase)
[recording, requirements] = make_valid_inputs();
recording.time = recording.time(1:end - 1);
verifyError(testCase, @() validate_raw_recording(recording, requirements), ...
    'validate_raw_recording:TimeDimensionMismatch');
end

function testDuplicateTimeRejected(testCase)
[recording, requirements] = make_valid_inputs();
recording.time(3) = recording.time(2);
verifyError(testCase, @() validate_raw_recording(recording, requirements), ...
    'validate_raw_recording:InvalidTime');
end

function testDecreasingTimeRejected(testCase)
[recording, requirements] = make_valid_inputs();
recording.time(3) = recording.time(2) - 0.01;
verifyError(testCase, @() validate_raw_recording(recording, requirements), ...
    'validate_raw_recording:InvalidTime');
end

function testNonfiniteTimeRejected(testCase)
[recording, requirements] = make_valid_inputs();
for value = [NaN Inf]
    candidate = recording;
    candidate.time(3) = value;
    verifyError(testCase, @() validate_raw_recording(candidate, requirements), ...
        'validate_raw_recording:InvalidTime');
end
end

function testMeasuredSamplingFrequencyCalculatedFromTime(testCase)
[recording, requirements] = make_valid_inputs();
report = validate_raw_recording(recording, requirements);
verifyEqual(testCase, report.median_sampling_interval_s, 0.02, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, report.measured_sampling_rate_hz, 50, ...
    'AbsTol', 1e-10);
end

function testSamplingRateWithinTolerancePasses(testCase)
[recording, requirements] = make_valid_inputs();
requirements.expected_sampling_rate_hz = 49.95;
requirements.sampling_rate_tolerance_hz = 0.1;
report = validate_raw_recording(recording, requirements);
verifyTrue(testCase, report.sampling_rate_within_tolerance);
verifyEqual(testCase, report.sampling_rate_deviation_hz, 0.05, ...
    'AbsTol', 1e-10);
end

function testSamplingRateFailureAndQcOrder(testCase)
[recording, requirements] = make_valid_inputs();
recording.time = [0; 0.02; 0.04; 0.061; 0.08; 0.10];
requirements.expected_sampling_rate_hz = 40;
requirements.sampling_rate_tolerance_hz = 0.1;
requirements.sampling_interval_tolerance_fraction = 0.01;
requirements.expected_channel_count = 29;
report = validate_raw_recording(recording, requirements);
verifyFalse(testCase, report.sampling_rate_within_tolerance);
verifyEqual(testCase, {report.qc_failures.check}.', ...
    {'sampling_rate'; 'sampling_interval_uniformity'; 'channel_count'});
verifyEqual(testCase, report.qc_failures(1).measured_value, ...
    report.measured_sampling_rate_hz);
verifyEqual(testCase, report.qc_failures(1).expected_value, 40);
verifyEqual(testCase, report.qc_failures(1).tolerance, 0.1);
verifyEqual(testCase, report.qc_failures(2).check, ...
    'sampling_interval_uniformity');
verifyEqual(testCase, report.qc_failures(2).measured_value, ...
    report.max_sampling_interval_relative_deviation);
verifyEqual(testCase, report.qc_failures(2).expected_value, 0);
verifyEqual(testCase, report.qc_failures(2).tolerance, ...
    requirements.sampling_interval_tolerance_fraction);
verifyEqual(testCase, report.qc_failures(3).check, 'channel_count');
verifyEqual(testCase, report.qc_failures(3).measured_value, ...
    report.channel_count);
verifyEqual(testCase, report.qc_failures(3).expected_value, ...
    requirements.expected_channel_count);
verifyEqual(testCase, report.qc_failures(3).tolerance, 0);
verifyFalse(testCase, report.all_acquisition_expectations_met);
end

function testUniformIntervalsPassTolerance(testCase)
[recording, requirements] = make_valid_inputs();
report = validate_raw_recording(recording, requirements);
verifyTrue(testCase, report.sampling_intervals_within_tolerance);
verifyLessThanOrEqual(testCase, ...
    report.max_sampling_interval_relative_deviation, ...
    requirements.sampling_interval_tolerance_fraction);
end

function testIrregularIntervalsProduceQcFailure(testCase)
[recording, requirements] = make_valid_inputs();
recording.time = [0; 0.02; 0.04; 0.061; 0.08; 0.10];
requirements.sampling_interval_tolerance_fraction = 0.01;
report = validate_raw_recording(recording, requirements);
verifyFalse(testCase, report.sampling_intervals_within_tolerance);
verifyTrue(testCase, any(strcmp({report.qc_failures.check}, ...
    'sampling_interval_uniformity')));
end

function testMeasurementCountMismatchRejected(testCase)
[recording, requirements] = make_valid_inputs();
recording.measurement_list(end) = [];
verifyError(testCase, @() validate_raw_recording(recording, requirements), ...
    'validate_raw_recording:MeasurementCountMismatch');
end

function testInvalidSourceIndicesRejected(testCase)
invalid = {0, -1, 1.5, NaN, Inf, 1 + 1i, '1', [1 2]};
verify_invalid_measurement_indices(testCase, 'source_index', invalid);
end

function testInvalidDetectorIndicesRejected(testCase)
invalid = {0, -1, 1.5, NaN, Inf, 1 + 1i, '1', [1 2]};
verify_invalid_measurement_indices(testCase, 'detector_index', invalid);
end

function testInvalidWavelengthIndicesRejected(testCase)
invalid = {0, -1, 1.5, 3, NaN, Inf, 1 + 1i, '1', [1 2]};
verify_invalid_measurement_indices(testCase, 'wavelength_index', invalid);
end

function testDuplicateMeasurementDefinitionRejected(testCase)
[recording, requirements] = make_valid_inputs();
recording.measurement_list(2).source_index = ...
    recording.measurement_list(1).source_index;
recording.measurement_list(2).detector_index = ...
    recording.measurement_list(1).detector_index;
recording.measurement_list(2).wavelength_index = ...
    recording.measurement_list(1).wavelength_index;
verifyError(testCase, @() validate_raw_recording(recording, requirements), ...
    'validate_raw_recording:DuplicateMeasurementDefinition');
end

function testThirtyChannelsDerivedFromSixtyMeasurements(testCase)
[recording, requirements] = make_valid_inputs();
report = validate_raw_recording(recording, requirements);
verifyEqual(testCase, report.measurement_count, 60);
verifyEqual(testCase, report.channel_count, 30);
verifySize(testCase, report.channel_pairs, [30 2]);
end

function testChannelCountMismatchIsReportOnly(testCase)
[recording, requirements] = make_valid_inputs();
requirements.expected_channel_count = 29;
report = validate_raw_recording(recording, requirements);
verifyEqual(testCase, report.channel_count, 30);
verifyFalse(testCase, report.channel_count_matches_expected);
verifyEqual(testCase, report.qc_failures(end).check, 'channel_count');
verifyEqual(testCase, report.qc_failures(end).measured_value, 30);
verifyEqual(testCase, report.qc_failures(end).expected_value, 29);
verifyEqual(testCase, report.qc_failures(end).tolerance, 0);
end

function testTwoArbitraryPositiveWavelengthsAccepted(testCase)
[recording, requirements] = make_valid_inputs();
recording.wavelengths_nm = [701 812]; % Synthetic values, not study values.
report = validate_raw_recording(recording, requirements);
verifyEqual(testCase, report.wavelengths_nm, [701 812]);
verifyEqual(testCase, report.wavelength_count, 2);
end

function testInvalidWavelengthMetadataRejected(testCase)
[recording, requirements] = make_valid_inputs();
invalid = {[], [0 800], [-1 800], [700 700], [700 NaN], ...
    [700 Inf], [700 800 + 1i], [700 800; 900 1000], '700'};
for index = 1:numel(invalid)
    candidate = recording;
    candidate.wavelengths_nm = invalid{index};
    verifyError(testCase, @() validate_raw_recording(candidate, requirements), ...
        'validate_raw_recording:InvalidWavelengths');
end
end

function testWavelengthCountMismatchRejected(testCase)
[recording, requirements] = make_valid_inputs();
recording.wavelengths_nm = [700 800 900];
verifyError(testCase, @() validate_raw_recording(recording, requirements), ...
    'validate_raw_recording:WavelengthCountMismatch');
end

function testMissingWavelengthMeasurementRejected(testCase)
[recording, requirements] = make_valid_inputs();
recording.measurement_list(2) = [];
recording.intensity(:, 2) = [];
verifyError(testCase, @() validate_raw_recording(recording, requirements), ...
    'validate_raw_recording:MissingWavelengthMeasurement');
end

function testChannelPairsPreserveFirstObservedOrder(testCase)
[recording, requirements] = make_valid_inputs();
order = [5 6 1 2 3 4 7:60];
recording.measurement_list = recording.measurement_list(order);
recording.intensity = recording.intensity(:, order);
report = validate_raw_recording(recording, requirements);
verifyEqual(testCase, report.channel_pairs(1:4, :), ...
    [3 1; 1 1; 2 1; 4 1]);
end

function testStructurallyValidStimuliAccepted(testCase)
[recording, requirements] = make_valid_inputs();
report = validate_raw_recording(recording, requirements);
verifyEqual(testCase, report.stimulus_definition_count, 1);
end

function testMissingStimuliRejected(testCase)
[recording, requirements] = make_valid_inputs();
recording = rmfield(recording, 'stimuli');
verifyError(testCase, @() validate_raw_recording(recording, requirements), ...
    'validate_raw_recording:MissingStimuli');
end

function testMalformedStimulusContainersRejected(testCase)
[recording, requirements] = make_valid_inputs();
invalid = {42, struct('name', 'EC'), struct('onsets', []), ...
    struct('name', 42, 'onsets', []), ...
    struct('name', 'EC', 'onsets', 'invalid'), ...
    struct('name', 'EC', 'onsets', [], 'durations', 'invalid')};
for index = 1:numel(invalid)
    candidate = recording;
    candidate.stimuli = invalid{index};
    verifyError(testCase, @() validate_raw_recording(candidate, requirements), ...
        'validate_raw_recording:InvalidStimulusContainer');
end
end

function testEmptyFieldDefinedStimulusArrayAccepted(testCase)
[recording, requirements] = make_valid_inputs();
recording.stimuli = struct('name', cell(0, 1), 'onsets', cell(0, 1));
report = validate_raw_recording(recording, requirements);
verifyEqual(testCase, report.stimulus_definition_count, 0);
end

function testCanonicalConditionPresenceNotChecked(testCase)
[recording, requirements] = make_valid_inputs();
recording.stimuli = struct('name', 'UNRELATED', 'onsets', []);
report = validate_raw_recording(recording, requirements);
verifyTrue(testCase, report.is_structurally_valid);
verifyEqual(testCase, report.stimulus_definition_count, 1);
end

function testSourceFormatsHaveIdenticalScientificValidation(testCase)
[recording, requirements] = make_valid_inputs();
recording.source_format = '.nirs';
nirs_report = validate_raw_recording(recording, requirements);
recording.source_format = '.snirf';
snirf_report = validate_raw_recording(recording, requirements);
verifyEqual(testCase, rmfield(nirs_report, 'source_format'), ...
    rmfield(snirf_report, 'source_format'));
verifyEqual(testCase, nirs_report.source_format, '.nirs');
verifyEqual(testCase, snirf_report.source_format, '.snirf');
end

function testArbitrarySourceFormatRemainsInformational(testCase)
[recording, requirements] = make_valid_inputs();
recording.source_format = "synthetic_adapter";
report = validate_raw_recording(recording, requirements);
verifyEqual(testCase, report.source_format, "synthetic_adapter");
verifyTrue(testCase, report.is_structurally_valid);
end

function testMalformedSourceFormatRejected(testCase)
[recording, requirements] = make_valid_inputs();
invalid = {'', string(missing), ["a" "b"], 42, ['ab'; 'cd']};
for index = 1:numel(invalid)
    candidate = recording;
    candidate.source_format = invalid{index};
    verifyError(testCase, @() validate_raw_recording(candidate, requirements), ...
        'validate_raw_recording:InvalidSourceFormat');
end
end

function testRecordingIsNotMutated(testCase)
[recording, requirements] = make_valid_inputs();
original = recording;
validate_raw_recording(recording, requirements);
verifyTrue(testCase, isequaln(recording, original));
end

function testRequirementsAreNotMutated(testCase)
[recording, requirements] = make_valid_inputs();
original = requirements;
validate_raw_recording(recording, requirements);
verifyTrue(testCase, isequaln(requirements, original));
end

function testSyntheticInMemoryValidationSucceeds(testCase)
% Code review, not this runtime test alone, verifies absence of file I/O.
[recording, requirements] = make_valid_inputs();
report = validate_raw_recording(recording, requirements);
verifyTrue(testCase, report.is_structurally_valid);
end

function testMissingSourceFormatAcceptedAsEmptyText(testCase)
[recording, requirements] = make_valid_inputs();
recording = rmfield(recording, 'source_format');
report = validate_raw_recording(recording, requirements);
verifyEqual(testCase, report.source_format, '');
end

function testInvalidExpectedSamplingRateRequirementsRejected(testCase)
[recording, requirements] = make_valid_inputs();
invalid = {-1, NaN, Inf, 50 + 1i, [50 50], '50'};
verify_invalid_requirement_values(testCase, recording, requirements, ...
    'expected_sampling_rate_hz', invalid);

missing_field = rmfield(requirements, 'expected_sampling_rate_hz');
verifyError(testCase, @() validate_raw_recording(recording, missing_field), ...
    'validate_raw_recording:InvalidRequirements');
extra_field = requirements;
extra_field.unapproved_field = 1;
verifyError(testCase, @() validate_raw_recording(recording, extra_field), ...
    'validate_raw_recording:InvalidRequirements');
end

function testZeroExpectedSamplingRateRejected(testCase)
[recording, requirements] = make_valid_inputs();
requirements.expected_sampling_rate_hz = 0;
verifyError(testCase, @() validate_raw_recording(recording, requirements), ...
    'validate_raw_recording:InvalidRequirements');
end

function testInvalidSamplingRateToleranceRequirementsRejected(testCase)
[recording, requirements] = make_valid_inputs();
invalid = {-1, NaN, Inf, 0.1 + 1i, [0.1 0.1], '0.1'};
verify_invalid_requirement_values(testCase, recording, requirements, ...
    'sampling_rate_tolerance_hz', invalid);
end

function testInvalidIntervalToleranceRequirementsRejected(testCase)
[recording, requirements] = make_valid_inputs();
invalid = {-1, NaN, Inf, 0.01 + 1i, [0.01 0.01], '0.01'};
verify_invalid_requirement_values(testCase, recording, requirements, ...
    'sampling_interval_tolerance_fraction', invalid);
end

function testExpectedChannelCountRequiresPositiveInteger(testCase)
[recording, requirements] = make_valid_inputs();
invalid = {0, -1, 30.5, NaN, Inf, 30 + 1i, [30 30], '30'};
verify_invalid_requirement_values(testCase, recording, requirements, ...
    'expected_channel_count', invalid);
end

function testExpectedWavelengthCountRequiresPositiveInteger(testCase)
[recording, requirements] = make_valid_inputs();
invalid = {0, -1, 2.5, NaN, Inf, 2 + 1i, [2 2], '2'};
verify_invalid_requirement_values(testCase, recording, requirements, ...
    'expected_wavelength_count', invalid);
end

function verify_invalid_measurement_indices(testCase, field_name, invalid)
for index = 1:numel(invalid)
    [recording, requirements] = make_valid_inputs();
    recording.measurement_list(1).(field_name) = invalid{index};
    verifyError(testCase, @() validate_raw_recording(recording, requirements), ...
        'validate_raw_recording:InvalidMeasurementIndex');
end
end

function verify_invalid_requirement_values( ...
        testCase, recording, requirements, field_name, invalid)
for index = 1:numel(invalid)
    candidate = requirements;
    candidate.(field_name) = invalid{index};
    verifyError(testCase, @() validate_raw_recording(recording, candidate), ...
        'validate_raw_recording:InvalidRequirements');
end
end

function [recording, requirements] = make_valid_inputs()
time = (0:5).' / 50;
measurement_count = 60;
intensity = 100 + reshape(1:(numel(time) * measurement_count), ...
    numel(time), measurement_count) / 1000;

measurement_template = struct('source_index', [], 'detector_index', [], ...
    'wavelength_index', []);
measurement_list = repmat(measurement_template, 1, measurement_count);
measurement_index = 0;
for channel_index = 1:30
    for wavelength_index = 1:2
        measurement_index = measurement_index + 1;
        measurement_list(measurement_index).source_index = channel_index;
        measurement_list(measurement_index).detector_index = 1;
        measurement_list(measurement_index).wavelength_index = wavelength_index;
    end
end

recording = struct();
recording.data_representation = 'raw_intensity';
recording.intensity = intensity;
recording.time = time;
recording.wavelengths_nm = [700 800]; % Arbitrary synthetic values.
recording.measurement_list = measurement_list;
recording.stimuli = struct('name', 'SYNTHETIC', 'onsets', [0; 0.05], ...
    'durations', [0.01; 0.01]);
recording.source_format = 'synthetic';

requirements = struct();
requirements.expected_sampling_rate_hz = 50;
requirements.sampling_rate_tolerance_hz = 0.1; % Test-only tolerance.
requirements.sampling_interval_tolerance_fraction = 1e-9; % Test-only.
requirements.expected_channel_count = 30;
requirements.expected_wavelength_count = 2;
end

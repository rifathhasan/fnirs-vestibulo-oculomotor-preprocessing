function tests = test_load_fnirs_recording
%TEST_LOAD_FNIRS_RECORDING Synthetic tests for the Homer .nirs adapter.
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
testCase.TestData.temp_directory = tempname;
mkdir(testCase.TestData.temp_directory);
end

function teardownOnce(testCase)
if testCase.TestData.path_was_added
    rmpath(testCase.TestData.function_directory);
end
if isfolder(testCase.TestData.temp_directory)
    rmdir(testCase.TestData.temp_directory, 's');
end
end

function testDispatcherAcceptsLowercaseNirs(testCase)
native = make_valid_native();
file_path = fullfile(testCase.TestData.temp_directory, 'lowercase.nirs');
write_nirs_fixture(file_path, native);
recording = load_fnirs_recording(file_path);
verifyEqual(testCase, recording.intensity, native.d);
end

function testDispatcherAcceptsUppercaseNirs(testCase)
native = make_valid_native();
file_path = fullfile(testCase.TestData.temp_directory, 'uppercase.NIRS');
write_nirs_fixture(file_path, native);
recording = load_fnirs_recording(file_path);
verifyEqual(testCase, recording.source_format, '.nirs');
end

function testDispatcherRejectsSnirf(testCase)
file_path = fullfile(testCase.TestData.temp_directory, 'unsupported.snirf');
write_text_file(file_path, 'synthetic unsupported fixture');
verifyError(testCase, @() load_fnirs_recording(file_path), ...
    'load_fnirs_recording:UnsupportedFileType');
end

function testDispatcherRejectsOtherExtension(testCase)
file_path = fullfile(testCase.TestData.temp_directory, 'unsupported.mat');
write_text_file(file_path, 'synthetic unsupported fixture');
verifyError(testCase, @() load_fnirs_recording(file_path), ...
    'load_fnirs_recording:UnsupportedFileType');
end

function testDispatcherRejectsInvalidPath(testCase)
verifyError(testCase, @() load_fnirs_recording(42), ...
    'load_fnirs_recording:InvalidFilePath');
end

function testDispatcherRejectsMissingFile(testCase)
file_path = fullfile(testCase.TestData.temp_directory, 'missing.nirs');
verifyError(testCase, @() load_fnirs_recording(file_path), ...
    'load_fnirs_recording:FileNotFound');
end

function testDispatcherRejectsUnreadableNirs(testCase)
file_path = fullfile(testCase.TestData.temp_directory, 'unreadable.nirs');
write_text_file(file_path, 'not a MAT file');
verifyError(testCase, @() load_fnirs_recording(file_path), ...
    'load_fnirs_recording:UnreadableFile');
end

function testDispatcherRejectsInvalidInputCount(testCase)
verifyError(testCase, @() load_fnirs_recording(), ...
    'load_fnirs_recording:InvalidInputCount');
end

function testNirsLoaderRejectsInvalidInputCount(testCase)
verifyError(testCase, @() load_nirs_recording(), ...
    'load_nirs_recording:InvalidInputCount');
end

function testNirsLoaderRejectsInvalidPath(testCase)
verifyError(testCase, @() load_nirs_recording(string(missing)), ...
    'load_nirs_recording:InvalidFilePath');
end

function testNirsLoaderRejectsMissingFile(testCase)
file_path = fullfile(testCase.TestData.temp_directory, 'direct_missing.nirs');
verifyError(testCase, @() load_nirs_recording(file_path), ...
    'load_nirs_recording:FileNotFound');
end

function testNirsLoaderRejectsUnreadableFile(testCase)
file_path = fullfile(testCase.TestData.temp_directory, 'direct_unreadable.nirs');
write_text_file(file_path, 'not a MAT file');
verifyError(testCase, @() load_nirs_recording(file_path), ...
    'load_nirs_recording:UnreadableFile');
end

function testValidNativeStructureTranslates(testCase)
recording = translate_nirs_structure(make_valid_native());
verifyEqual(testCase, size(recording.intensity), [5 4]);
verifyEqual(testCase, numel(recording.measurement_list), 4);
verifyEqual(testCase, numel(recording.stimuli), 3);
end

function testCanonicalRepresentationAndSourceFormat(testCase)
recording = translate_nirs_structure(make_valid_native());
verifyEqual(testCase, recording.data_representation, 'raw_intensity');
verifyEqual(testCase, recording.source_format, '.nirs');
end

function testIntensityPreservedExactly(testCase)
native = make_valid_native();
recording = translate_nirs_structure(native);
verifyEqual(testCase, recording.intensity, native.d);
end

function testTimePreservedExactly(testCase)
native = make_valid_native();
native.t = [0 0.03 0.09 0.14 0.22];
recording = translate_nirs_structure(native);
verifyEqual(testCase, recording.time, native.t);
end

function testMissingRawIntensityRejected(testCase)
native = rmfield(make_valid_native(), 'd');
verifyError(testCase, @() translate_nirs_structure(native), ...
    'load_nirs_recording:MissingRawIntensity');
end

function testMalformedRawIntensityRejected(testCase)
native = make_valid_native();
native.d = 'not numeric';
verifyError(testCase, @() translate_nirs_structure(native), ...
    'load_nirs_recording:InvalidNativeStructure');
end

function testMissingTimeRejected(testCase)
native = rmfield(make_valid_native(), 't');
verifyError(testCase, @() translate_nirs_structure(native), ...
    'load_nirs_recording:MissingTime');
end

function testMalformedTimeRejected(testCase)
native = make_valid_native();
native.t = {'not numeric'};
verifyError(testCase, @() translate_nirs_structure(native), ...
    'load_nirs_recording:InvalidNativeStructure');
end

function testMissingProbeMetadataRejected(testCase)
native = rmfield(make_valid_native(), 'SD');
verifyError(testCase, @() translate_nirs_structure(native), ...
    'load_nirs_recording:MissingProbeMetadata');
end

function testMalformedProbeMetadataRejected(testCase)
native = make_valid_native();
native.SD = 7;
verifyError(testCase, @() translate_nirs_structure(native), ...
    'load_nirs_recording:MissingProbeMetadata');
end

function testMissingMeasurementListRejected(testCase)
native = make_valid_native();
native.SD = rmfield(native.SD, 'MeasList');
verifyError(testCase, @() translate_nirs_structure(native), ...
    'load_nirs_recording:MissingMeasurementList');
end

function testMalformedMeasurementListRejected(testCase)
native = make_valid_native();
native.SD.MeasList = ones(4, 3);
verifyError(testCase, @() translate_nirs_structure(native), ...
    'load_nirs_recording:InvalidNativeStructure');
end

function testMissingWavelengthMetadataRejected(testCase)
native = make_valid_native();
native.SD = rmfield(native.SD, 'Lambda');
verifyError(testCase, @() translate_nirs_structure(native), ...
    'load_nirs_recording:MissingWavelengthMetadata');
end

function testMalformedWavelengthMetadataRejected(testCase)
native = make_valid_native();
native.SD.Lambda = {'synthetic'};
verifyError(testCase, @() translate_nirs_structure(native), ...
    'load_nirs_recording:InvalidNativeStructure');
end

function testTimeIntensityRowMismatchRejected(testCase)
native = make_valid_native();
native.t = native.t(1:end-1);
verifyError(testCase, @() translate_nirs_structure(native), ...
    'load_nirs_recording:IncompatibleDimensions');
end

function testIntensityMeasurementCountMismatchRejected(testCase)
native = make_valid_native();
native.SD.MeasList = native.SD.MeasList(1:end-1, :);
verifyError(testCase, @() translate_nirs_structure(native), ...
    'load_nirs_recording:IncompatibleDimensions');
end

function testTransposedLookingIntensityRejectedWithoutTranspose(testCase)
native = make_valid_native();
native.d = native.d.';
verifyError(testCase, @() translate_nirs_structure(native), ...
    'load_nirs_recording:IncompatibleDimensions');
end

function testMeasurementRowsRemainInOriginalOrder(testCase)
native = make_valid_native();
native.SD.MeasList = [3 2 90 2; 1 4 80 1; 2 1 70 2; 1 2 60 1];
recording = translate_nirs_structure(native);
actual = [[recording.measurement_list.source_index].', ...
    [recording.measurement_list.detector_index].', ...
    [recording.measurement_list.wavelength_index].'];
verifyEqual(testCase, actual, native.SD.MeasList(:, [1 2 4]));
end

function testMeasurementColumnsOneTwoAndFourMappedExactly(testCase)
native = make_valid_native();
native.SD.MeasList = [7 9 101 2; 4 8 202 1; 6 3 303 2; 5 1 404 1];
recording = translate_nirs_structure(native);
verifyEqual(testCase, [recording.measurement_list.source_index].', [7; 4; 6; 5]);
verifyEqual(testCase, [recording.measurement_list.detector_index].', [9; 8; 3; 1]);
verifyEqual(testCase, [recording.measurement_list.wavelength_index].', [2; 1; 2; 1]);
end

function testLegacyColumnThreeIsNotCopied(testCase)
native = make_valid_native();
native.SD.MeasList(:, 3) = [11; 22; 33; 44];
recording = translate_nirs_structure(native);
verifyEqual(testCase, sort(fieldnames(recording.measurement_list)), ...
    sort({'source_index'; 'detector_index'; 'wavelength_index'}));
verifyEqual(testCase, [recording.measurement_list.wavelength_index].', ...
    native.SD.MeasList(:, 4));
end

function testWavelengthValuesAndOrderPreserved(testCase)
native = make_valid_native();
% These arbitrary values are synthetic and are not historical CW6 wavelengths.
native.SD.Lambda = [911 733];
recording = translate_nirs_structure(native);
verifyEqual(testCase, recording.wavelengths_nm, [911 733]);
end

function testBinaryImpulseStimulusAccepted(testCase)
native = make_valid_native();
recording = translate_nirs_structure(native);
verifyEqual(testCase, numel(recording.stimuli), size(native.s, 2));
end

function testImpulseRowsMapToExactTimeValues(testCase)
native = make_valid_native();
native.t = [0; 0.02; 0.05; 0.11; 0.20];
recording = translate_nirs_structure(native);
verifyEqual(testCase, recording.stimuli(2).onsets, native.t([2 4]));
verifyEqual(testCase, recording.stimuli(3).onsets, native.t(3));
end

function testStimulusDurationsAreEmpty(testCase)
recording = translate_nirs_structure(make_valid_native());
for index = 1:numel(recording.stimuli)
    verifyEmpty(testCase, recording.stimuli(index).durations);
end
end

function testNonbinaryPositiveStimulusRejected(testCase)
native = make_valid_native();
native.s(2, 2) = 0.5;
verifyError(testCase, @() translate_nirs_structure(native), ...
    'load_nirs_recording:UnsupportedStimulusEncoding');
end

function testNegativeStimulusRejected(testCase)
native = make_valid_native();
native.s(2, 2) = -1;
verifyError(testCase, @() translate_nirs_structure(native), ...
    'load_nirs_recording:UnsupportedStimulusEncoding');
end

function testConsecutiveActiveStimulusSamplesRejected(testCase)
native = make_valid_native();
native.s(2:3, 2) = 1;
verifyError(testCase, @() translate_nirs_structure(native), ...
    'load_nirs_recording:UnsupportedStimulusEncoding');
end

function testAllZeroNamedColumnPreserved(testCase)
recording = translate_nirs_structure(make_valid_native());
verifyEqual(testCase, recording.stimuli(1).name, '1');
verifyEmpty(testCase, recording.stimuli(1).onsets);
verifyEmpty(testCase, recording.stimuli(1).durations);
end

function testConditionNamesPreservedWithoutNormalization(testCase)
native = make_valid_native();
native.CondNames = {'1', '  ec ', 'hVor'};
recording = translate_nirs_structure(native);
verifyEqual(testCase, {recording.stimuli.name}, native.CondNames);
end

function testMissingStimulusMatrixRejected(testCase)
native = rmfield(make_valid_native(), 's');
verifyError(testCase, @() translate_nirs_structure(native), ...
    'load_nirs_recording:MissingStimulusMetadata');
end

function testMissingConditionNamesRejected(testCase)
native = rmfield(make_valid_native(), 'CondNames');
verifyError(testCase, @() translate_nirs_structure(native), ...
    'load_nirs_recording:MissingStimulusNames');
end

function testConditionNameCountMismatchRejected(testCase)
native = make_valid_native();
native.CondNames = native.CondNames(1:2);
verifyError(testCase, @() translate_nirs_structure(native), ...
    'load_nirs_recording:MissingStimulusNames');
end

function testMalformedConditionNameRejected(testCase)
native = make_valid_native();
native.CondNames{2} = 12;
verifyError(testCase, @() translate_nirs_structure(native), ...
    'load_nirs_recording:MissingStimulusNames');
end

function testStimulusTimeRowMismatchRejected(testCase)
native = make_valid_native();
native.s = native.s(1:end-1, :);
verifyError(testCase, @() translate_nirs_structure(native), ...
    'load_nirs_recording:IncompatibleDimensions');
end

function testMalformedStimulusMatrixRejected(testCase)
native = make_valid_native();
native.s = complex(native.s, 1);
verifyError(testCase, @() translate_nirs_structure(native), ...
    'load_nirs_recording:MalformedNativeStimulus');
end

function testFixtureUsesTopLevelNativeVariables(testCase)
native = make_valid_native();
file_path = fullfile(testCase.TestData.temp_directory, 'top_level.nirs');
write_nirs_fixture(file_path, native);
loaded = load(file_path, '-mat');
verifyTrue(testCase, all(isfield(loaded, {'d', 't', 'SD', 's', 'CondNames'})));
verifyFalse(testCase, isfield(loaded, 'native'));
verifyEqual(testCase, sort(fieldnames(loaded)), ...
    sort({'d'; 't'; 'SD'; 's'; 'CondNames'}));
end

function testTranslationDoesNotMutateNativeInput(testCase)
native = make_valid_native();
saved_copy = native;
translate_nirs_structure(native);
verifyTrue(testCase, isequaln(native, saved_copy));
end

function testLoadedRecordingPassesRawValidator(testCase)
native = make_valid_native();
file_path = fullfile(testCase.TestData.temp_directory, 'validator_input.nirs');
write_nirs_fixture(file_path, native);
recording = load_fnirs_recording(file_path);

% These requirements match this synthetic fixture and are test-only values.
requirements.expected_sampling_rate_hz = 50;
requirements.sampling_rate_tolerance_hz = 0.1;
requirements.sampling_interval_tolerance_fraction = 1e-9;
requirements.expected_channel_count = 2;
requirements.expected_wavelength_count = 2;

report = validate_raw_recording(recording, requirements);

verifyTrue(testCase, report.is_structurally_valid);
verifyTrue(testCase, report.all_acquisition_expectations_met);
verifyEqual(testCase, report.measurement_count, 4);
verifyEqual(testCase, report.channel_count, 2);
verifyEqual(testCase, report.wavelength_count, 2);
verifyEqual(testCase, report.measured_sampling_rate_hz, 50, ...
    'AbsTol', 1e-12);
verifyEmpty(testCase, report.qc_failures);
end

function testTranslatorReturnsAdapterContextSourceFormat(testCase)
native = make_valid_native();
[~, adapter_context] = translate_nirs_structure(native);
verifyEqual(testCase, adapter_context.source_format, '.nirs');
end

function testTranslatorPreservesNativeSdExactly(testCase)
native = make_valid_native();
[~, adapter_context] = translate_nirs_structure(native);
verifyTrue(testCase, isequaln(adapter_context.homer2_sd, native.SD));
end

function testNirsLoaderReturnsAdapterContext(testCase)
native = make_valid_native();
file_path = fullfile(testCase.TestData.temp_directory, 'nirs_context.nirs');
write_nirs_fixture(file_path, native);
[~, adapter_context] = load_nirs_recording(file_path);
verifyEqual(testCase, adapter_context.source_format, '.nirs');
verifyTrue(testCase, isequaln(adapter_context.homer2_sd, native.SD));
end

function testDispatcherForwardsAdapterContext(testCase)
native = make_valid_native();
file_path = fullfile(testCase.TestData.temp_directory, 'dispatcher_context.nirs');
write_nirs_fixture(file_path, native);
[~, adapter_context] = load_fnirs_recording(file_path);
verifyEqual(testCase, adapter_context.source_format, '.nirs');
verifyTrue(testCase, isequaln(adapter_context.homer2_sd, native.SD));
end

function testOneOutputTranslatorRemainsUnchanged(testCase)
native = make_valid_native();
recording_one_output = translate_nirs_structure(native);
[recording_two_outputs, ~] = translate_nirs_structure(native);
verifyTrue(testCase, isequaln(recording_one_output, recording_two_outputs));
end

function testOneOutputNirsLoaderRemainsUnchanged(testCase)
native = make_valid_native();
file_path = fullfile(testCase.TestData.temp_directory, 'nirs_one_output.nirs');
write_nirs_fixture(file_path, native);
recording_one_output = load_nirs_recording(file_path);
[recording_two_outputs, ~] = load_nirs_recording(file_path);
verifyTrue(testCase, isequaln(recording_one_output, recording_two_outputs));
end

function testOneOutputDispatcherRemainsUnchanged(testCase)
native = make_valid_native();
file_path = fullfile(testCase.TestData.temp_directory, 'dispatcher_one_output.nirs');
write_nirs_fixture(file_path, native);
recording_one_output = load_fnirs_recording(file_path);
[recording_two_outputs, ~] = load_fnirs_recording(file_path);
verifyTrue(testCase, isequaln(recording_one_output, recording_two_outputs));
end

function testAdapterContextRequestDoesNotMutateInputsOrRecording(testCase)
native = make_valid_native();
saved_native = native;
recording_before_context_request = translate_nirs_structure(native);
[recording_after_context_request, adapter_context] = ...
    translate_nirs_structure(native);
verifyTrue(testCase, isequaln(native, saved_native));
verifyTrue(testCase, isequaln(adapter_context.homer2_sd, saved_native.SD));
verifyTrue(testCase, isequaln( ...
    recording_after_context_request, recording_before_context_request));
end

function native = make_valid_native()
native = struct();
native.d = reshape(101:120, 5, 4);
native.t = (0:4).' / 50;
native.SD = struct();
native.SD.MeasList = [2 3 0 1; 2 3 0 2; 1 4 0 1; 1 4 0 2];
% Arbitrary synthetic values; they are not historical CW6 wavelengths.
native.SD.Lambda = [701 899];
% Synthetic test-only geometry and metadata; not historical study values.
native.SD.SrcPos = [0 0 0; 30 0 0];
native.SD.DetPos = [10 20 0; 20 20 0; 30 20 0; 40 20 0];
native.SD.MeasListAct = [1; 1; 1; 1];
native.SD.SpatialUnit = 'mm';
native.s = [0 0 0; 0 1 0; 0 0 1; 0 1 0; 0 0 0];
native.CondNames = {'1', '  EC ', 'hvor'};
end

function write_nirs_fixture(file_path, native)
d = native.d;
t = native.t;
SD = native.SD;
s = native.s;
CondNames = native.CondNames;
save(file_path, 'd', 't', 'SD', 's', 'CondNames', '-mat');
end

function write_text_file(file_path, contents)
file_identifier = fopen(file_path, 'w');
if file_identifier == -1
    error('test_load_fnirs_recording:FixtureCreationFailed', ...
        'Could not create the synthetic test fixture.');
end
cleanup = onCleanup(@() fclose(file_identifier));
fprintf(file_identifier, '%s', contents);
clear cleanup;
end

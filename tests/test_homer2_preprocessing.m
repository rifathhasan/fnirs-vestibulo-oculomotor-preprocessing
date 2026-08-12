function tests = test_homer2_preprocessing
%TEST_HOMER2_PREPROCESSING Synthetic contract tests for Homer2 wrappers.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
test_file = mfilename('fullpath');
repository_root = fileparts(fileparts(test_file));
function_directory = fullfile(repository_root, 'src', 'individual');
path_entries = strsplit(path, pathsep);
testCase.TestData.function_directory = function_directory;
testCase.TestData.function_path_was_added = ...
    ~any(strcmp(path_entries, function_directory));
if testCase.TestData.function_path_was_added
    addpath(function_directory);
end
end

function teardownOnce(testCase)
if testCase.TestData.function_path_was_added
    rmpath(testCase.TestData.function_directory);
end
end

function setup(testCase)
testCase.TestData.original_path = path;
testCase.TestData.stub_directory = tempname;
mkdir(testCase.TestData.stub_directory);
write_homer_stubs(testCase.TestData.stub_directory);
addpath(testCase.TestData.stub_directory, '-begin');
clear_stub_functions();
rehash;
global HOMER2_STUB_STATE
HOMER2_STUB_STATE = struct();
end

function teardown(testCase)
path(testCase.TestData.original_path);
clear_stub_functions();
rehash;
global HOMER2_STUB_STATE
HOMER2_STUB_STATE = [];
clear global HOMER2_STUB_STATE
if isfolder(testCase.TestData.stub_directory)
    rmdir(testCase.TestData.stub_directory, 's');
end
end

function testIntensityForwardsInputUnchanged(testCase)
global HOMER2_STUB_STATE
intensity = valid_intensity();
homer2_intensity_to_od(intensity);
verifyTrue(testCase, isequaln(HOMER2_STUB_STATE.intensity_input, intensity));
end

function testIntensityReturnsConfiguredOutput(testCase)
global HOMER2_STUB_STATE
intensity = valid_intensity();
HOMER2_STUB_STATE.intensity_output = reshape(21:32, 4, 3);
actual = homer2_intensity_to_od(intensity);
verifyEqual(testCase, actual, HOMER2_STUB_STATE.intensity_output);
end

function testIntensityRejectsMalformedInput(testCase)
invalid = {[], 'invalid', complex(ones(2)), [1 NaN], reshape(1:8,2,2,2)};
for index = 1:numel(invalid)
    verifyError(testCase, @() homer2_intensity_to_od(invalid{index}), ...
        'homer2_preprocessing:InvalidInput');
end
end

function testIntensityRejectsNonpositiveInput(testCase)
for value = [0 -1]
    intensity = valid_intensity();
    intensity(1) = value;
    verifyError(testCase, @() homer2_intensity_to_od(intensity), ...
        'homer2_preprocessing:InvalidInput');
end
end

function testIntensityReportsMissingDependency(testCase)
isolate_missing_dependency(testCase, 'hmrIntensity2OD');
verifyError(testCase, @() homer2_intensity_to_od(valid_intensity()), ...
    'homer2_preprocessing:MissingDependency');
end

function testIntensityRetainsExternalFailureCause(testCase)
global HOMER2_STUB_STATE
HOMER2_STUB_STATE.intensity_error_identifier = 'synthetic:intensityFailure';
exception = capture_exception(@() homer2_intensity_to_od(valid_intensity()));
verify_external_cause(testCase, exception, 'synthetic:intensityFailure');
end

function testIntensityRejectsInvalidOutputs(testCase)
global HOMER2_STUB_STATE
intensity = valid_intensity();
invalid = {NaN(size(intensity)), ones(3,3)};
for index = 1:numel(invalid)
    HOMER2_STUB_STATE.intensity_output = invalid{index};
    verifyError(testCase, @() homer2_intensity_to_od(intensity), ...
        'homer2_preprocessing:InvalidOutput');
end
end

function testWaveletForwardsOdUnchanged(testCase)
global HOMER2_STUB_STATE
od = valid_od();
homer2_wavelet_correct_od(od, valid_sd(), 0.75);
verifyTrue(testCase, isequaln(HOMER2_STUB_STATE.wavelet_od, od));
end

function testWaveletForwardsFullSdUnchanged(testCase)
global HOMER2_STUB_STATE
sd = valid_sd();
homer2_wavelet_correct_od(valid_od(), sd, 0.75);
verifyTrue(testCase, isequaln(HOMER2_STUB_STATE.wavelet_sd, sd));
end

function testWaveletForwardsIqrAndExplicitTurnon(testCase)
global HOMER2_STUB_STATE
homer2_wavelet_correct_od(valid_od(), valid_sd(), 0.75);
verifyEqual(testCase, HOMER2_STUB_STATE.wavelet_iqr, 0.75);
verifyEqual(testCase, HOMER2_STUB_STATE.wavelet_turnon, 1);
end

function testWaveletAcceptsValidBinaryActivityWithoutNormalization(testCase)
global HOMER2_STUB_STATE
sd = valid_sd();
sd.MeasListAct = logical([1 0 1 0]);
homer2_wavelet_correct_od(valid_od(), sd, 0.5);
verifyTrue(testCase, isequaln( ...
    HOMER2_STUB_STATE.wavelet_sd.MeasListAct, sd.MeasListAct));
end

function testWaveletRejectsMissingMeasListAct(testCase)
sd = rmfield(valid_sd(), 'MeasListAct');
verifyError(testCase, @() homer2_wavelet_correct_od(valid_od(), sd, 0.5), ...
    'homer2_preprocessing:InvalidProbeMetadata');
end

function testWaveletRejectsWrongActivityCountOrShape(testCase)
invalid = {[1 1 1], ones(2,2)};
for index = 1:numel(invalid)
    sd = valid_sd();
    sd.MeasListAct = invalid{index};
    verifyError(testCase, ...
        @() homer2_wavelet_correct_od(valid_od(), sd, 0.5), ...
        'homer2_preprocessing:InvalidProbeMetadata');
end
end

function testWaveletRejectsNonbinaryActivity(testCase)
sd = valid_sd();
sd.MeasListAct = [1 0.5 1 0];
verifyError(testCase, @() homer2_wavelet_correct_od(valid_od(), sd, 0.5), ...
    'homer2_preprocessing:InvalidProbeMetadata');
end

function testWaveletRejectsInvalidIqr(testCase)
invalid = {-1, NaN, Inf, [1 2], 'invalid'};
for index = 1:numel(invalid)
    verifyError(testCase, ...
        @() homer2_wavelet_correct_od(valid_od(), valid_sd(), invalid{index}), ...
        'homer2_preprocessing:InvalidParameter');
end
end

function testWaveletReportsMissingDependency(testCase)
isolate_missing_dependency(testCase, 'hmrMotionCorrectWavelet');
verifyError(testCase, ...
    @() homer2_wavelet_correct_od(valid_od(), valid_sd(), 0.5), ...
    'homer2_preprocessing:MissingDependency');
end

function testWaveletRetainsExternalFailureCause(testCase)
global HOMER2_STUB_STATE
HOMER2_STUB_STATE.wavelet_error_identifier = 'synthetic:waveletFailure';
exception = capture_exception(@() ...
    homer2_wavelet_correct_od(valid_od(), valid_sd(), 0.5));
verify_external_cause(testCase, exception, 'synthetic:waveletFailure');
end

function testWaveletRejectsInvalidOutputs(testCase)
global HOMER2_STUB_STATE
od = valid_od();
invalid = {Inf(size(od)), ones(size(od,1), size(od,2)-1)};
for index = 1:numel(invalid)
    HOMER2_STUB_STATE.wavelet_output = invalid{index};
    verifyError(testCase, ...
        @() homer2_wavelet_correct_od(od, valid_sd(), 0.5), ...
        'homer2_preprocessing:InvalidOutput');
end
end

function testBandpassForwardsAllArgumentsUnchanged(testCase)
global HOMER2_STUB_STATE
od = valid_od();
homer2_bandpass_od(od, 20, 0.2, 2);
verifyTrue(testCase, isequaln(HOMER2_STUB_STATE.filter_od, od));
verifyEqual(testCase, HOMER2_STUB_STATE.filter_sampling_rate, 20);
verifyEqual(testCase, HOMER2_STUB_STATE.filter_low, 0.2);
verifyEqual(testCase, HOMER2_STUB_STATE.filter_high, 2);
verifyEqual(testCase, HOMER2_STUB_STATE.filter_call_count, 1);
end

function testBandpassReturnsConfiguredFirstOutput(testCase)
global HOMER2_STUB_STATE
od = valid_od();
HOMER2_STUB_STATE.filter_output = od + 4;
HOMER2_STUB_STATE.filter_second_output = od + 99;
actual = homer2_bandpass_od(od, 20, 0.2, 2);
verifyEqual(testCase, actual, od + 4);
end

function testBandpassRejectsMalformedOd(testCase)
invalid = {[], 'invalid', complex(ones(2)), [1 Inf]};
for index = 1:numel(invalid)
    verifyError(testCase, @() homer2_bandpass_od(invalid{index},20,0.2,2), ...
        'homer2_preprocessing:InvalidInput');
end
end

function testBandpassRejectsInvalidSamplingRate(testCase)
invalid = {0, -1, NaN, Inf, [20 20], 'invalid'};
for index = 1:numel(invalid)
    verifyError(testCase, ...
        @() homer2_bandpass_od(valid_od(), invalid{index}, 0.2, 2), ...
        'homer2_preprocessing:InvalidParameter');
end
end

function testBandpassRejectsInvalidCutoffOrdering(testCase)
invalid = {[0 2], [-1 2], [2 2], [3 2], [0.2 0]};
for index = 1:numel(invalid)
    cutoffs = invalid{index};
    verifyError(testCase, ...
        @() homer2_bandpass_od(valid_od(),20,cutoffs(1),cutoffs(2)), ...
        'homer2_preprocessing:InvalidParameter');
end
end

function testBandpassRejectsHighCutoffEqualToNyquist(testCase)
verifyError(testCase, @() homer2_bandpass_od(valid_od(),20,0.2,10), ...
    'homer2_preprocessing:InvalidParameter');
end

function testBandpassRejectsHighCutoffAboveNyquist(testCase)
verifyError(testCase, @() homer2_bandpass_od(valid_od(),20,0.2,11), ...
    'homer2_preprocessing:InvalidParameter');
end

function testBandpassReportsMissingDependency(testCase)
isolate_missing_dependency(testCase, 'hmrBandpassFilt');
verifyError(testCase, @() homer2_bandpass_od(valid_od(),20,0.2,2), ...
    'homer2_preprocessing:MissingDependency');
end

function testBandpassRetainsExternalFailureCause(testCase)
global HOMER2_STUB_STATE
HOMER2_STUB_STATE.filter_error_identifier = 'synthetic:filterFailure';
exception = capture_exception(@() ...
    homer2_bandpass_od(valid_od(),20,0.2,2));
verify_external_cause(testCase, exception, 'synthetic:filterFailure');
end

function testBandpassRejectsInvalidOutputs(testCase)
global HOMER2_STUB_STATE
od = valid_od();
invalid = {NaN(size(od)), ones(size(od,1)-1,size(od,2))};
for index = 1:numel(invalid)
    HOMER2_STUB_STATE.filter_output = invalid{index};
    verifyError(testCase, @() homer2_bandpass_od(od,20,0.2,2), ...
        'homer2_preprocessing:InvalidOutput');
end
end

function testMbllForwardsOdSdAndDpfUnchanged(testCase)
global HOMER2_STUB_STATE
od = valid_od();
sd = valid_sd();
dpf = [1.2 2.3];
configure_valid_dc(od, sd);
homer2_od_to_concentration(od, sd, dpf);
verifyTrue(testCase, isequaln(HOMER2_STUB_STATE.mbll_od, od));
verifyTrue(testCase, isequaln(HOMER2_STUB_STATE.mbll_sd, sd));
verifyTrue(testCase, isequaln(HOMER2_STUB_STATE.mbll_dpf, dpf));
end

function testMbllRejectsColumnDpf(testCase)
verifyError(testCase, ...
    @() homer2_od_to_concentration(valid_od(),valid_sd(),[1; 2]), ...
    'homer2_preprocessing:InvalidParameter');
end

function testMbllRejectsInvalidDpfValuesOrCount(testCase)
invalid = {[1], [1 2 3], [1 0], [1 -2], [1 NaN], [1 Inf], 'invalid'};
for index = 1:numel(invalid)
    verifyError(testCase, ...
        @() homer2_od_to_concentration(valid_od(),valid_sd(),invalid{index}), ...
        'homer2_preprocessing:InvalidParameter');
end
end

function testMbllRejectsMissingRequiredProbeFields(testCase)
fields = {'Lambda', 'MeasList', 'SrcPos', 'DetPos'};
for index = 1:numel(fields)
    sd = rmfield(valid_sd(), fields{index});
    verifyError(testCase, ...
        @() homer2_od_to_concentration(valid_od(),sd,[1 2]), ...
        'homer2_preprocessing:InvalidProbeMetadata');
end
end

function testMbllAcceptsAbsentSpatialUnit(testCase)
sd = rmfield(valid_sd(), 'SpatialUnit');
configure_valid_dc(valid_od(), sd);
concentration = homer2_od_to_concentration(valid_od(), sd, [1 2]);
verifySize(testCase, concentration.HbO, [5 2]);
end

function testMbllAcceptsMillimeterSpatialUnit(testCase)
sd = valid_sd();
sd.SpatialUnit = 'MM';
configure_valid_dc(valid_od(), sd);
concentration = homer2_od_to_concentration(valid_od(), sd, [1 2]);
verifySize(testCase, concentration.HbR, [5 2]);
end

function testMbllAcceptsCentimeterSpatialUnit(testCase)
sd = valid_sd();
sd.SpatialUnit = "cm";
configure_valid_dc(valid_od(), sd);
concentration = homer2_od_to_concentration(valid_od(), sd, [1 2]);
verifySize(testCase, concentration.HbO, [5 2]);
end

function testMbllRejectsUnsupportedSpatialUnit(testCase)
invalid = {'meters', '', ["mm" "cm"], 7};
for index = 1:numel(invalid)
    sd = valid_sd();
    sd.SpatialUnit = invalid{index};
    verifyError(testCase, ...
        @() homer2_od_to_concentration(valid_od(),sd,[1 2]), ...
        'homer2_preprocessing:InvalidProbeMetadata');
end
end

function testMbllRejectsInvalidMeasurementIndices(testCase)
invalid_sd = cell(3,1);
invalid_sd{1} = valid_sd(); invalid_sd{1}.MeasList(1,1) = 0;
invalid_sd{2} = valid_sd(); invalid_sd{2}.MeasList(1,2) = 99;
invalid_sd{3} = valid_sd(); invalid_sd{3}.MeasList(1,4) = 3;
for index = 1:numel(invalid_sd)
    verifyError(testCase, ...
        @() homer2_od_to_concentration(valid_od(),invalid_sd{index},[1 2]), ...
        'homer2_preprocessing:InvalidProbeMetadata');
end
end

function testMbllRejectsZeroDistanceGeometry(testCase)
sd = valid_sd();
sd.DetPos(1,:) = sd.SrcPos(2,:);
verifyError(testCase, ...
    @() homer2_od_to_concentration(valid_od(),sd,[1 2]), ...
    'homer2_preprocessing:InvalidProbeMetadata');
end

function testMbllRejectsIncompleteWavelengthLayout(testCase)
sd = valid_sd();
sd.MeasList = [2 1 0 1; 1 2 0 1; 1 2 0 2];
od = valid_od(); od = od(:,1:3);
verifyError(testCase, @() homer2_od_to_concentration(od,sd,[1 2]), ...
    'homer2_preprocessing:InvalidProbeMetadata');
end

function testMbllRejectsDuplicateMeasurementDefinition(testCase)
sd = valid_sd();
sd.MeasList(2,:) = sd.MeasList(1,:);
verifyError(testCase, ...
    @() homer2_od_to_concentration(valid_od(),sd,[1 2]), ...
    'homer2_preprocessing:InvalidProbeMetadata');
end

function testMbllRejectsMisorderedAdditionalWavelengths(testCase)
sd = one_channel_sd();
sd.Lambda = [710 810 910]; % Synthetic test-only wavelengths.
sd.MeasList = [1 1 0 1; 1 1 0 3; 1 1 0 2];
sd.MeasListAct = [1; 1; 1];
od = reshape(1:15,5,3) / 100;
verifyError(testCase, ...
    @() homer2_od_to_concentration(od,sd,[1 2 3]), ...
    'homer2_preprocessing:InvalidProbeMetadata');
end

function testMbllPreservesAnchorRowChannelOrder(testCase)
od = valid_od(); sd = valid_sd();
configure_valid_dc(od, sd);
concentration = homer2_od_to_concentration(od,sd,[1 2]);
verifyEqual(testCase, concentration.channel_pairs, [2 1; 1 2]);
end

function testMbllReturnsOnlyApprovedFields(testCase)
od = valid_od(); sd = valid_sd();
configure_valid_dc(od, sd);
concentration = homer2_od_to_concentration(od,sd,[1 2]);
verifyEqual(testCase, sort(fieldnames(concentration)), ...
    sort({'HbO'; 'HbR'; 'channel_pairs'}));
verifyFalse(testCase, isfield(concentration, 'HbT'));
verifyFalse(testCase, isfield(concentration, 'units'));
end

function testMbllExtractsHbOAndHbRWithoutCollapse(testCase)
global HOMER2_STUB_STATE
od = valid_od(); sd = valid_sd();
dc = zeros(5,3,2);
dc(:,1,1) = (1:5).'; dc(:,1,2) = (11:15).';
dc(:,2,1) = -(1:5).'; dc(:,2,2) = -(11:15).';
dc(:,3,:) = dc(:,1,:) + dc(:,2,:);
HOMER2_STUB_STATE.mbll_output = dc;
concentration = homer2_od_to_concentration(od,sd,[1 2]);
verifyEqual(testCase, concentration.HbO, [dc(:,1,1) dc(:,1,2)]);
verifyEqual(testCase, concentration.HbR, [dc(:,2,1) dc(:,2,2)]);
end

function testMbllPreservesOneChannelDimensions(testCase)
global HOMER2_STUB_STATE
sd = one_channel_sd();
od = reshape(1:10,5,2) / 100;
dc = zeros(5,3,1);
dc(:,1,1) = (1:5).'; dc(:,2,1) = -(1:5).';
HOMER2_STUB_STATE.mbll_output = dc;
concentration = homer2_od_to_concentration(od,sd,[1 2]);
verifySize(testCase, concentration.HbO, [5 1]);
verifySize(testCase, concentration.HbR, [5 1]);
verifySize(testCase, concentration.channel_pairs, [1 2]);
end

function testMbllReportsMissingDependency(testCase)
isolate_missing_dependency(testCase, 'hmrOD2Conc');
verifyError(testCase, ...
    @() homer2_od_to_concentration(valid_od(),valid_sd(),[1 2]), ...
    'homer2_preprocessing:MissingDependency');
end

function testMbllRetainsExternalFailureCause(testCase)
global HOMER2_STUB_STATE
HOMER2_STUB_STATE.mbll_error_identifier = 'synthetic:mbllFailure';
exception = capture_exception(@() ...
    homer2_od_to_concentration(valid_od(),valid_sd(),[1 2]));
verify_external_cause(testCase, exception, 'synthetic:mbllFailure');
end

function testMbllRejectsInvalidDimensions(testCase)
global HOMER2_STUB_STATE
invalid = {zeros(4,3,2), zeros(5,2,2), zeros(5,3,3)};
for index = 1:numel(invalid)
    HOMER2_STUB_STATE.mbll_output = invalid{index};
    verifyError(testCase, ...
        @() homer2_od_to_concentration(valid_od(),valid_sd(),[1 2]), ...
        'homer2_preprocessing:InvalidOutput');
end
end

function testMbllRejectsNonfiniteOutput(testCase)
global HOMER2_STUB_STATE
dc = zeros(5,3,2); dc(1) = NaN;
HOMER2_STUB_STATE.mbll_output = dc;
verifyError(testCase, ...
    @() homer2_od_to_concentration(valid_od(),valid_sd(),[1 2]), ...
    'homer2_preprocessing:InvalidOutput');
end

function testFactoryReturnsExactlyFourHandles(testCase)
operators = homer2_preprocessing_operators(valid_sd());
verifyEqual(testCase, sort(fieldnames(operators)), sort({ ...
    'intensity_to_od'; 'wavelet_correct_od'; ...
    'bandpass_od'; 'od_to_concentration'}));
fields = fieldnames(operators);
for index = 1:numel(fields)
    verifyTrue(testCase, isa(operators.(fields{index}), 'function_handle'));
end
end

function testFactoryCapturesSdWithoutMutation(testCase)
global HOMER2_STUB_STATE
sd = valid_sd(); saved_sd = sd;
operators = homer2_preprocessing_operators(sd);
sd.MeasListAct(:) = 0;
operators.wavelet_correct_od(valid_od(), 0.5);
verifyTrue(testCase, isequaln(HOMER2_STUB_STATE.wavelet_sd, saved_sd));
end

function testFactoryPerformsNoCallsAndNeedsNoDependencies(testCase)
global HOMER2_STUB_STATE
names = homer_dependency_names();
for index = 1:numel(names)
    isolate_missing_dependency(testCase, names{index});
end
operators = homer2_preprocessing_operators(valid_sd());
verifyTrue(testCase, isstruct(operators));
verifyEmpty(testCase, fieldnames(HOMER2_STUB_STATE));
end

function testFactoryHandlesUseApprovedSignatures(testCase)
global HOMER2_STUB_STATE
sd = valid_sd(); od = valid_od();
operators = homer2_preprocessing_operators(sd);
operators.intensity_to_od(valid_intensity());
operators.wavelet_correct_od(od, 0.75);
operators.bandpass_od(od, 20, 0.2, 2);
configure_valid_dc(od, sd);
operators.od_to_concentration(od, [1 2]);
verifyEqual(testCase, HOMER2_STUB_STATE.wavelet_turnon, 1);
verifyEqual(testCase, HOMER2_STUB_STATE.filter_sampling_rate, 20);
verifyTrue(testCase, isequaln(HOMER2_STUB_STATE.mbll_sd, sd));
end

function testFactoryAndWrappersRejectInvalidInputCounts(testCase)
verifyError(testCase, @() homer2_preprocessing_operators(), ...
    'homer2_preprocessing:InvalidInputCount');
verifyError(testCase, @() homer2_intensity_to_od(), ...
    'homer2_preprocessing:InvalidInputCount');
verifyError(testCase, @() homer2_wavelet_correct_od(), ...
    'homer2_preprocessing:InvalidInputCount');
verifyError(testCase, @() homer2_bandpass_od(), ...
    'homer2_preprocessing:InvalidInputCount');
verifyError(testCase, @() homer2_od_to_concentration(), ...
    'homer2_preprocessing:InvalidInputCount');
verifyError(testCase, @() homer2_preprocessing_operators(7), ...
    'homer2_preprocessing:InvalidProbeMetadata');
end

function intensity = valid_intensity()
intensity = reshape(11:22, 4, 3);
end

function od = valid_od()
od = reshape(1:20, 5, 4) / 100;
end

function sd = valid_sd()
sd = struct();
% Synthetic test-only wavelengths and geometry; not historical study values.
sd.Lambda = [701 899];
sd.MeasList = [2 1 0 1; 2 1 0 2; 1 2 0 1; 1 2 0 2];
sd.MeasListAct = [1; 0; 1; 1];
sd.SrcPos = [0 0 0; 30 0 0];
sd.DetPos = [10 20 0; 40 20 0];
sd.SpatialUnit = 'mm';
sd.UnrelatedNativeMetadata = struct('preserve', true);
end

function sd = one_channel_sd()
sd = struct();
% Synthetic test-only wavelengths and geometry; not historical study values.
sd.Lambda = [711 911];
sd.MeasList = [1 1 0 1; 1 1 0 2];
sd.MeasListAct = [1; 1];
sd.SrcPos = [0 0 0];
sd.DetPos = [30 0 0];
sd.SpatialUnit = 'mm';
end

function configure_valid_dc(od, sd)
global HOMER2_STUB_STATE
channel_count = nnz(sd.MeasList(:,4) == 1);
dc = zeros(size(od,1), 3, channel_count);
for channel = 1:channel_count
    dc(:,1,channel) = channel + (1:size(od,1)).';
    dc(:,2,channel) = -channel - (1:size(od,1)).';
end
dc(:,3,:) = dc(:,1,:) + dc(:,2,:);
HOMER2_STUB_STATE.mbll_output = dc;
end

function exception = capture_exception(function_handle)
exception = [];
try
    function_handle();
catch caught
    exception = caught;
end
end

function verify_external_cause(testCase, exception, expected_identifier)
verifyNotEmpty(testCase, exception);
verifyEqual(testCase, exception.identifier, ...
    'homer2_preprocessing:ExternalCallFailed');
verifyNotEmpty(testCase, exception.cause);
verifyEqual(testCase, exception.cause{1}.identifier, expected_identifier);
end

function isolate_missing_dependency(testCase, function_name)
stub_path = fullfile(testCase.TestData.stub_directory, ...
    [function_name '.m']);
if isfile(stub_path)
    delete(stub_path);
end
clear_named_function(function_name);
rehash;

locations = which(function_name, '-all');
if ischar(locations)
    locations = cellstr(locations);
end
for index = 1:numel(locations)
    directory = fileparts(locations{index});
    if ~isempty(directory) && path_contains(directory)
        rmpath(directory);
    end
end
clear_named_function(function_name);
rehash;
verifyEqual(testCase, exist(function_name, 'file'), 0, ...
    sprintf('Could not isolate dependency %s from the MATLAB path.', ...
    function_name));
end

function present = path_contains(directory)
entries = strsplit(path, pathsep);
present = any(strcmp(entries, directory));
end

function clear_stub_functions()
names = homer_dependency_names();
for index = 1:numel(names)
    clear_named_function(names{index});
end
end

function clear_named_function(function_name)
eval(sprintf('clear %s', function_name));
end

function names = homer_dependency_names()
names = {'hmrIntensity2OD', 'hmrMotionCorrectWavelet', ...
    'hmrBandpassFilt', 'hmrOD2Conc'};
end

function write_homer_stubs(directory)
write_stub_file(fullfile(directory, 'hmrIntensity2OD.m'), {
    'function od = hmrIntensity2OD(intensity)'
    'global HOMER2_STUB_STATE'
    'HOMER2_STUB_STATE.intensity_input = intensity;'
    'if isfield(HOMER2_STUB_STATE,''intensity_error_identifier'')'
    '    error(HOMER2_STUB_STATE.intensity_error_identifier,''Synthetic external failure.'');'
    'end'
    'if isfield(HOMER2_STUB_STATE,''intensity_output'')'
    '    od = HOMER2_STUB_STATE.intensity_output;'
    'else'
    '    od = intensity;'
    'end'
    'end'});

write_stub_file(fullfile(directory, 'hmrMotionCorrectWavelet.m'), {
    'function corrected = hmrMotionCorrectWavelet(od, sd, iqr, turnon)'
    'global HOMER2_STUB_STATE'
    'HOMER2_STUB_STATE.wavelet_od = od;'
    'HOMER2_STUB_STATE.wavelet_sd = sd;'
    'HOMER2_STUB_STATE.wavelet_iqr = iqr;'
    'HOMER2_STUB_STATE.wavelet_turnon = turnon;'
    'if isfield(HOMER2_STUB_STATE,''wavelet_error_identifier'')'
    '    error(HOMER2_STUB_STATE.wavelet_error_identifier,''Synthetic external failure.'');'
    'end'
    'if isfield(HOMER2_STUB_STATE,''wavelet_output'')'
    '    corrected = HOMER2_STUB_STATE.wavelet_output;'
    'else'
    '    corrected = od;'
    'end'
    'end'});

write_stub_file(fullfile(directory, 'hmrBandpassFilt.m'), {
    'function [filtered, lowpass] = hmrBandpassFilt(od, fs, low, high)'
    'global HOMER2_STUB_STATE'
    'HOMER2_STUB_STATE.filter_od = od;'
    'HOMER2_STUB_STATE.filter_sampling_rate = fs;'
    'HOMER2_STUB_STATE.filter_low = low;'
    'HOMER2_STUB_STATE.filter_high = high;'
    'if ~isfield(HOMER2_STUB_STATE,''filter_call_count'')'
    '    HOMER2_STUB_STATE.filter_call_count = 0;'
    'end'
    'HOMER2_STUB_STATE.filter_call_count = HOMER2_STUB_STATE.filter_call_count + 1;'
    'if isfield(HOMER2_STUB_STATE,''filter_error_identifier'')'
    '    error(HOMER2_STUB_STATE.filter_error_identifier,''Synthetic external failure.'');'
    'end'
    'if isfield(HOMER2_STUB_STATE,''filter_output'')'
    '    filtered = HOMER2_STUB_STATE.filter_output;'
    'else'
    '    filtered = od;'
    'end'
    'if isfield(HOMER2_STUB_STATE,''filter_second_output'')'
    '    lowpass = HOMER2_STUB_STATE.filter_second_output;'
    'else'
    '    lowpass = od;'
    'end'
    'end'});

write_stub_file(fullfile(directory, 'hmrOD2Conc.m'), {
    'function dc = hmrOD2Conc(od, sd, dpf)'
    'global HOMER2_STUB_STATE'
    'HOMER2_STUB_STATE.mbll_od = od;'
    'HOMER2_STUB_STATE.mbll_sd = sd;'
    'HOMER2_STUB_STATE.mbll_dpf = dpf;'
    'if isfield(HOMER2_STUB_STATE,''mbll_error_identifier'')'
    '    error(HOMER2_STUB_STATE.mbll_error_identifier,''Synthetic external failure.'');'
    'end'
    'if ~isfield(HOMER2_STUB_STATE,''mbll_output'')'
    '    error(''synthetic:MissingConfiguredOutput'',''MBLL stub output was not configured.'');'
    'end'
    'dc = HOMER2_STUB_STATE.mbll_output;'
    'end'});
end

function write_stub_file(file_path, lines)
file_identifier = fopen(file_path, 'w');
if file_identifier == -1
    error('test_homer2_preprocessing:StubCreationFailed', ...
        'Could not create a temporary Homer2 stub.');
end
cleanup = onCleanup(@() fclose(file_identifier));
for index = 1:numel(lines)
    fprintf(file_identifier, '%s\n', lines{index});
end
clear cleanup;
end

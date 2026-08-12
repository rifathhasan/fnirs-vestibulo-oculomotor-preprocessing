function report = validate_raw_recording(recording, requirements)
%VALIDATE_RAW_RECORDING Validate standardized raw fNIRS recording metadata.
%   REPORT = VALIDATE_RAW_RECORDING(RECORDING, REQUIREMENTS) validates an
%   in-memory recording before optical-density conversion. The function
%   inspects metadata and raw intensity only; it does not load files, mutate
%   inputs, reorder measurements, repair metadata, or process signals.
%
%   RECORDING is a scalar structure with fields:
%     data_representation - Scalar text equal to raw_intensity after
%                           trimming and case-insensitive comparison.
%     intensity           - Positive finite real time-by-measurement matrix.
%     time                - Finite real strictly increasing time vector.
%     wavelengths_nm      - Positive finite real unique wavelength vector.
%     measurement_list    - Struct array mapping each intensity column with
%                           source_index, detector_index, wavelength_index.
%     stimuli             - Struct array with name and onsets fields and an
%                           optional durations field.
%     source_format       - Optional nonempty scalar text; informational.
%
%   REQUIREMENTS is a scalar structure containing exactly:
%     expected_sampling_rate_hz, sampling_rate_tolerance_hz,
%     sampling_interval_tolerance_fraction, expected_channel_count, and
%     expected_wavelength_count. Tolerances are supplied by the caller.
%
%   REPORT contains structural facts and acquisition-expectation QC. A
%   successful return means structural validation passed. Sampling-rate,
%   interval-uniformity, and channel-count mismatches are report-only QC.

if nargin ~= 2
    error('validate_raw_recording:InvalidInputCount', ...
        'validate_raw_recording requires exactly two inputs.');
end

validate_requirements(requirements);

if ~isstruct(recording) || ~isscalar(recording)
    error('validate_raw_recording:InvalidRecording', ...
        'recording must be a scalar structure.');
end
required_recording_fields = {'data_representation', 'intensity', 'time', ...
    'wavelengths_nm', 'measurement_list'};
if ~all(isfield(recording, required_recording_fields))
    error('validate_raw_recording:InvalidRecording', ...
        'recording is missing one or more required acquisition fields.');
end
if ~isfield(recording, 'stimuli')
    error('validate_raw_recording:MissingStimuli', ...
        'recording must contain a stimuli field.');
end

representation = scalar_text(recording.data_representation);
if isempty(representation) || ...
        ~strcmpi(strtrim(representation), 'raw_intensity')
    error('validate_raw_recording:InvalidDataRepresentation', ...
        'data_representation must explicitly identify raw_intensity.');
end

intensity = recording.intensity;
if ~isnumeric(intensity) || ~isreal(intensity) || isempty(intensity) || ...
        ~ismatrix(intensity) || any(~isfinite(intensity(:))) || ...
        any(intensity(:) <= 0)
    error('validate_raw_recording:InvalidIntensity', ...
        ['intensity must be a nonempty, finite, real, strictly positive ' ...
         '2-D time-by-measurement numeric matrix.']);
end

time = recording.time;
if ~isnumeric(time) || ~isreal(time) || ~isvector(time) || isempty(time) || ...
        any(~isfinite(time(:)))
    error('validate_raw_recording:InvalidTime', ...
        'time must be a nonempty, finite, real numeric vector.');
end
time = time(:);
if numel(time) < 2
    error('validate_raw_recording:InsufficientTimeSamples', ...
        'time must contain at least two samples.');
end
if numel(time) ~= size(intensity, 1)
    error('validate_raw_recording:TimeDimensionMismatch', ...
        'time must contain exactly one value per intensity row.');
end
if any(diff(time) <= 0)
    error('validate_raw_recording:InvalidTime', ...
        'time must be strictly increasing with no duplicate values.');
end

wavelengths = recording.wavelengths_nm;
if ~isnumeric(wavelengths) || ~isreal(wavelengths) || ...
        ~isvector(wavelengths) || isempty(wavelengths) || ...
        any(~isfinite(wavelengths(:))) || any(wavelengths(:) <= 0) || ...
        numel(unique(wavelengths(:))) ~= numel(wavelengths)
    error('validate_raw_recording:InvalidWavelengths', ...
        'wavelengths_nm must be a positive, finite, real, unique vector.');
end
wavelength_count = numel(wavelengths);
if wavelength_count ~= requirements.expected_wavelength_count
    error('validate_raw_recording:WavelengthCountMismatch', ...
        'Wavelength count must equal expected_wavelength_count.');
end

measurement_list = recording.measurement_list;
measurement_fields = {'source_index', 'detector_index', 'wavelength_index'};
if ~isstruct(measurement_list) || ...
        ~isequal(sort(fieldnames(measurement_list)), sort(measurement_fields(:)))
    error('validate_raw_recording:InvalidMeasurementList', ...
        ['measurement_list must be a struct array containing exactly ' ...
         'source_index, detector_index, and wavelength_index.']);
end
measurement_list = measurement_list(:);
measurement_count = numel(measurement_list);
if measurement_count ~= size(intensity, 2)
    error('validate_raw_recording:MeasurementCountMismatch', ...
        ['measurement_list must contain exactly one element per ' ...
         'intensity column.']);
end

source_indices = zeros(measurement_count, 1);
detector_indices = zeros(measurement_count, 1);
wavelength_indices = zeros(measurement_count, 1);
for measurement_index = 1:measurement_count
    source_indices(measurement_index) = validate_measurement_index( ...
        measurement_list(measurement_index).source_index, Inf);
    detector_indices(measurement_index) = validate_measurement_index( ...
        measurement_list(measurement_index).detector_index, Inf);
    wavelength_indices(measurement_index) = validate_measurement_index( ...
        measurement_list(measurement_index).wavelength_index, ...
        wavelength_count);
end

measurement_definitions = [source_indices detector_indices wavelength_indices];
if size(unique(measurement_definitions, 'rows'), 1) ~= measurement_count
    error('validate_raw_recording:DuplicateMeasurementDefinition', ...
        ['Each source-detector-wavelength measurement definition must ' ...
         'appear exactly once.']);
end

source_detector_pairs = [source_indices detector_indices];
channel_pairs = unique(source_detector_pairs, 'rows', 'stable');
channel_count = size(channel_pairs, 1);
for channel_index = 1:channel_count
    channel_mask = source_indices == channel_pairs(channel_index, 1) & ...
        detector_indices == channel_pairs(channel_index, 2);
    for wavelength_index = 1:requirements.expected_wavelength_count
        if nnz(channel_mask & wavelength_indices == wavelength_index) ~= 1
            error('validate_raw_recording:MissingWavelengthMeasurement', ...
                ['Every source-detector channel must contain exactly one ' ...
                 'measurement for every required wavelength index.']);
        end
    end
end

stimuli = recording.stimuli;
if ~isstruct(stimuli) || ~isfield(stimuli, 'name') || ...
        ~isfield(stimuli, 'onsets')
    error('validate_raw_recording:InvalidStimulusContainer', ...
        'stimuli must be a struct array with name and onsets fields.');
end
stimuli = stimuli(:);
stimuli_have_durations = isfield(stimuli, 'durations');
for stimulus_index = 1:numel(stimuli)
    if isempty(scalar_text(stimuli(stimulus_index).name))
        error('validate_raw_recording:InvalidStimulusContainer', ...
            'Each stimulus name must be nonempty scalar text.');
    end
    onsets = stimuli(stimulus_index).onsets;
    if ~isnumeric(onsets) || ~(isvector(onsets) || isempty(onsets))
        error('validate_raw_recording:InvalidStimulusContainer', ...
            'Each stimulus onsets value must be a numeric vector or empty.');
    end
    if stimuli_have_durations
        durations = stimuli(stimulus_index).durations;
        if ~isnumeric(durations) || ...
                ~(isvector(durations) || isempty(durations))
            error('validate_raw_recording:InvalidStimulusContainer', ...
                ['Each stimulus durations value must be a numeric vector ' ...
                 'or empty when the field is present.']);
        end
    end
end

source_format = '';
if isfield(recording, 'source_format')
    source_format = recording.source_format;
    if ~is_valid_source_format(source_format)
        error('validate_raw_recording:InvalidSourceFormat', ...
            'source_format must be nonempty scalar text when supplied.');
    end
end

sampling_intervals_s = diff(time);
median_sampling_interval_s = median(sampling_intervals_s);
measured_sampling_rate_hz = 1 / median_sampling_interval_s;
sampling_rate_deviation_hz = abs(measured_sampling_rate_hz - ...
    requirements.expected_sampling_rate_hz);
sampling_rate_within_tolerance = sampling_rate_deviation_hz <= ...
    requirements.sampling_rate_tolerance_hz;
max_sampling_interval_relative_deviation = ...
    max(abs(sampling_intervals_s - median_sampling_interval_s)) / ...
    median_sampling_interval_s;
sampling_intervals_within_tolerance = ...
    max_sampling_interval_relative_deviation <= ...
    requirements.sampling_interval_tolerance_fraction;
channel_count_matches_expected = ...
    channel_count == requirements.expected_channel_count;

report.is_structurally_valid = true;
report.data_representation = 'raw_intensity';
report.time_sample_count = numel(time);
report.measurement_count = measurement_count;
report.median_sampling_interval_s = median_sampling_interval_s;
report.measured_sampling_rate_hz = measured_sampling_rate_hz;
report.expected_sampling_rate_hz = requirements.expected_sampling_rate_hz;
report.sampling_rate_tolerance_hz = requirements.sampling_rate_tolerance_hz;
report.sampling_rate_deviation_hz = sampling_rate_deviation_hz;
report.sampling_rate_within_tolerance = sampling_rate_within_tolerance;
report.max_sampling_interval_relative_deviation = ...
    max_sampling_interval_relative_deviation;
report.sampling_interval_tolerance_fraction = ...
    requirements.sampling_interval_tolerance_fraction;
report.sampling_intervals_within_tolerance = ...
    sampling_intervals_within_tolerance;
report.channel_count = channel_count;
report.expected_channel_count = requirements.expected_channel_count;
report.channel_count_matches_expected = channel_count_matches_expected;
report.channel_pairs = channel_pairs;
report.wavelength_count = wavelength_count;
report.expected_wavelength_count = requirements.expected_wavelength_count;
report.wavelength_count_matches_expected = true;
report.wavelengths_nm = recording.wavelengths_nm;
report.stimulus_definition_count = numel(stimuli);
report.source_format = source_format;

failure_template = struct('check', '', 'measured_value', [], ...
    'expected_value', [], 'tolerance', []);
report.qc_failures = repmat(failure_template, 0, 1);
if ~sampling_rate_within_tolerance
    report.qc_failures(end + 1, 1) = make_failure(failure_template, ...
        'sampling_rate', measured_sampling_rate_hz, ...
        requirements.expected_sampling_rate_hz, ...
        requirements.sampling_rate_tolerance_hz);
end
if ~sampling_intervals_within_tolerance
    report.qc_failures(end + 1, 1) = make_failure(failure_template, ...
        'sampling_interval_uniformity', ...
        max_sampling_interval_relative_deviation, 0, ...
        requirements.sampling_interval_tolerance_fraction);
end
if ~channel_count_matches_expected
    report.qc_failures(end + 1, 1) = make_failure(failure_template, ...
        'channel_count', channel_count, ...
        requirements.expected_channel_count, 0);
end
report.all_acquisition_expectations_met = ...
    report.sampling_rate_within_tolerance && ...
    report.sampling_intervals_within_tolerance && ...
    report.channel_count_matches_expected;
end

function validate_requirements(requirements)
required_fields = {'expected_sampling_rate_hz', ...
    'sampling_rate_tolerance_hz', ...
    'sampling_interval_tolerance_fraction', ...
    'expected_channel_count', 'expected_wavelength_count'};
if ~isstruct(requirements) || ~isscalar(requirements) || ...
        ~isequal(sort(fieldnames(requirements)), sort(required_fields(:)))
    error('validate_raw_recording:InvalidRequirements', ...
        'requirements must contain exactly the five required fields.');
end
if ~is_finite_real_scalar(requirements.expected_sampling_rate_hz) || ...
        requirements.expected_sampling_rate_hz <= 0 || ...
        ~is_finite_real_scalar(requirements.sampling_rate_tolerance_hz) || ...
        requirements.sampling_rate_tolerance_hz < 0 || ...
        ~is_finite_real_scalar( ...
        requirements.sampling_interval_tolerance_fraction) || ...
        requirements.sampling_interval_tolerance_fraction < 0 || ...
        ~is_positive_integer_scalar(requirements.expected_channel_count) || ...
        ~is_positive_integer_scalar(requirements.expected_wavelength_count)
    error('validate_raw_recording:InvalidRequirements', ...
        'One or more requirements values are invalid.');
end
end

function tf = is_finite_real_scalar(value)
tf = isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value);
end

function tf = is_positive_integer_scalar(value)
tf = is_finite_real_scalar(value) && value > 0 && fix(value) == value;
end

function value = validate_measurement_index(value, maximum)
if ~is_positive_integer_scalar(value) || value > maximum
    error('validate_raw_recording:InvalidMeasurementIndex', ...
        ['Measurement indices must be finite positive integer scalars, ' ...
         'and wavelength indices must reference supplied wavelengths.']);
end
value = double(value);
end

function text = scalar_text(value)
text = '';
if ischar(value) && isvector(value) && ~isempty(value)
    text = value(:).';
elseif isstring(value) && isscalar(value) && ~ismissing(value) && ...
        strlength(value) > 0
    text = char(value);
end
end

function tf = is_valid_source_format(value)
tf = (ischar(value) && isvector(value) && ~isempty(value)) || ...
    (isstring(value) && isscalar(value) && ~ismissing(value) && ...
    strlength(value) > 0);
end

function failure = make_failure(template, check, measured, expected, tolerance)
failure = template;
failure.check = check;
failure.measured_value = measured;
failure.expected_value = expected;
failure.tolerance = tolerance;
end

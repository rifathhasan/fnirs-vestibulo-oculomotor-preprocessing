function [recording, adapter_context] = translate_nirs_structure(native)
%TRANSLATE_NIRS_STRUCTURE Translate a native Homer .nirs structure.
%   RECORDING = TRANSLATE_NIRS_STRUCTURE(NATIVE) translates standardized
%   fields from an in-memory Homer .nirs structure. NATIVE.d must be raw
%   intensity arranged as time-by-measurement, NATIVE.t is acquisition time,
%   NATIVE.SD contains MeasList and Lambda, and NATIVE.s with CondNames
%   describes binary stimulus-onset impulses.
%   [RECORDING, ADAPTER_CONTEXT] additionally returns format-specific
%   metadata. ADAPTER_CONTEXT.HOMER2_SD is copied directly from NATIVE.SD
%   without reconstruction, normalization, or scientific interpretation.
%
%   RECORDING preserves intensity, time, wavelength, measurement, stimulus,
%   and name ordering. No values are sorted, transposed, inferred, repaired,
%   filtered, or otherwise scientifically processed. Detailed acquisition
%   validation belongs to validate_raw_recording.

if nargin ~= 1
    error('load_nirs_recording:InvalidInputCount', ...
        'translate_nirs_structure requires exactly one input.');
end
if ~isstruct(native) || ~isscalar(native)
    error('load_nirs_recording:InvalidNativeStructure', ...
        'native must be a scalar structure loaded from a .nirs file.');
end

if ~isfield(native, 'd')
    error('load_nirs_recording:MissingRawIntensity', ...
        'The native .nirs structure must contain raw intensity field d.');
end
intensity = native.d;
if ~isnumeric(intensity) || ~isreal(intensity) || isempty(intensity) || ...
        ~ismatrix(intensity)
    error('load_nirs_recording:InvalidNativeStructure', ...
        'Native d must be a nonempty real numeric 2-D matrix.');
end

if ~isfield(native, 't')
    error('load_nirs_recording:MissingTime', ...
        'The native .nirs structure must contain acquisition time field t.');
end
time = native.t;
if ~isnumeric(time) || ~isreal(time) || ~isvector(time) || isempty(time)
    error('load_nirs_recording:InvalidNativeStructure', ...
        'Native t must be a nonempty real numeric vector.');
end

if ~isfield(native, 'SD') || ~isstruct(native.SD) || ~isscalar(native.SD)
    error('load_nirs_recording:MissingProbeMetadata', ...
        'The native .nirs structure must contain scalar probe structure SD.');
end
if ~isfield(native.SD, 'MeasList')
    error('load_nirs_recording:MissingMeasurementList', ...
        'Native SD must contain MeasList.');
end
measurement_matrix = native.SD.MeasList;
if ~isnumeric(measurement_matrix) || ~isreal(measurement_matrix) || ...
        ~ismatrix(measurement_matrix) || size(measurement_matrix, 2) < 4
    error('load_nirs_recording:InvalidNativeStructure', ...
        'Native SD.MeasList must be a real numeric 2-D matrix with at least four columns.');
end

if ~isfield(native.SD, 'Lambda')
    error('load_nirs_recording:MissingWavelengthMetadata', ...
        'Native SD must contain the ordered wavelength vector Lambda.');
end
wavelengths = native.SD.Lambda;
if ~isnumeric(wavelengths) || ~isreal(wavelengths) || ...
        ~isvector(wavelengths) || isempty(wavelengths)
    error('load_nirs_recording:InvalidNativeStructure', ...
        'Native SD.Lambda must be a nonempty real numeric vector.');
end

if size(intensity, 1) ~= numel(time) || ...
        size(intensity, 2) ~= size(measurement_matrix, 1)
    error('load_nirs_recording:IncompatibleDimensions', ...
        ['Native d must be time-by-measurement, with one row per t value ' ...
         'and one column per SD.MeasList row.']);
end

if ~isfield(native, 's')
    error('load_nirs_recording:MissingStimulusMetadata', ...
        'The native .nirs structure must contain stimulus matrix s.');
end
stimulus_matrix = native.s;
if ~(isnumeric(stimulus_matrix) || islogical(stimulus_matrix)) || ...
        ~isreal(stimulus_matrix) || ~ismatrix(stimulus_matrix) || ...
        any(~isfinite(stimulus_matrix(:)))
    error('load_nirs_recording:MalformedNativeStimulus', ...
        'Native s must be a finite real numeric or logical 2-D matrix.');
end
if size(stimulus_matrix, 1) ~= numel(time)
    error('load_nirs_recording:IncompatibleDimensions', ...
        'Native s must contain exactly one row per t value.');
end
if any(stimulus_matrix(:) ~= 0 & stimulus_matrix(:) ~= 1)
    error('load_nirs_recording:UnsupportedStimulusEncoding', ...
        'Native s supports only exact binary values 0 and 1.');
end
if size(stimulus_matrix, 1) > 1 && any(any( ...
        stimulus_matrix(1:end-1, :) == 1 & ...
        stimulus_matrix(2:end, :) == 1))
    error('load_nirs_recording:UnsupportedStimulusEncoding', ...
        'Consecutive active stimulus samples are not supported.');
end

if ~isfield(native, 'CondNames')
    error('load_nirs_recording:MissingStimulusNames', ...
        'The native .nirs structure must contain CondNames.');
end
condition_names = validate_condition_names( ...
    native.CondNames, size(stimulus_matrix, 2));

measurement_count = size(measurement_matrix, 1);
measurement_list = repmat(struct( ...
    'source_index', [], 'detector_index', [], 'wavelength_index', []), ...
    measurement_count, 1);
for measurement_index = 1:measurement_count
    measurement_list(measurement_index).source_index = ...
        measurement_matrix(measurement_index, 1);
    measurement_list(measurement_index).detector_index = ...
        measurement_matrix(measurement_index, 2);
    measurement_list(measurement_index).wavelength_index = ...
        measurement_matrix(measurement_index, 4);
end

stimulus_count = size(stimulus_matrix, 2);
stimuli = repmat(struct('name', [], 'onsets', [], 'durations', []), ...
    stimulus_count, 1);
for stimulus_index = 1:stimulus_count
    event_rows = find(stimulus_matrix(:, stimulus_index) == 1);
    stimuli(stimulus_index).name = condition_names{stimulus_index};
    stimuli(stimulus_index).onsets = time(event_rows);
    stimuli(stimulus_index).durations = [];
end

recording = struct();
recording.data_representation = 'raw_intensity';
recording.intensity = intensity;
recording.time = time;
recording.wavelengths_nm = wavelengths;
recording.measurement_list = measurement_list;
recording.stimuli = stimuli;
recording.source_format = '.nirs';

adapter_context = struct();
adapter_context.source_format = '.nirs';
adapter_context.homer2_sd = native.SD;
end

function condition_names = validate_condition_names(value, expected_count)
if iscell(value) && isvector(value)
    condition_names = value(:);
elseif isstring(value) && isvector(value)
    condition_names = cell(numel(value), 1);
    for index = 1:numel(value)
        condition_names{index} = value(index);
    end
elseif ischar(value) && isrow(value) && expected_count == 1
    condition_names = {value};
else
    error('load_nirs_recording:MissingStimulusNames', ...
        'CondNames must provide exactly one scalar-text name per stimulus column.');
end

if numel(condition_names) ~= expected_count
    error('load_nirs_recording:MissingStimulusNames', ...
        'CondNames must provide exactly one name per stimulus column.');
end
for index = 1:numel(condition_names)
    name = condition_names{index};
    if ischar(name)
        valid = isrow(name) && ~isempty(name);
    elseif isstring(name)
        valid = isscalar(name) && ~ismissing(name) && strlength(name) > 0;
    else
        valid = false;
    end
    if ~valid
        error('load_nirs_recording:MissingStimulusNames', ...
            'Every CondNames entry must be nonempty scalar text.');
    end
end
end

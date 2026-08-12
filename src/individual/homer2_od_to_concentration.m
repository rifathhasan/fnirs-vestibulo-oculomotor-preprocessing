function concentration = homer2_od_to_concentration( ...
        filtered_od, homer2_sd, dpf)
%HOMER2_OD_TO_CONCENTRATION Convert OD using legacy Homer2 MBLL.
%   CONCENTRATION = HOMER2_OD_TO_CONCENTRATION(FILTERED_OD, HOMER2_SD, DPF)
%   forwards finite real time-by-measurement optical density, the complete
%   native SD structure, and one positive row-vector DPF value per
%   wavelength to hmrOD2Conc.
%
%   CONCENTRATION contains:
%     HbO           - time-by-channel oxyhemoglobin concentration values.
%     HbR           - time-by-channel deoxyhemoglobin concentration values.
%     channel_pairs - channel-by-2 [source detector] pairs in the exact
%                     wavelength-index-1 anchor order used by Homer2.
%
%   The legacy source does not explicitly establish final concentration
%   units, so this wrapper does not assign a units label. HbT is omitted.

if nargin ~= 3
    error('homer2_preprocessing:InvalidInputCount', ...
        'homer2_od_to_concentration requires exactly three inputs.');
end
validate_od(filtered_od);
[channel_pairs, wavelength_count] = validate_probe( ...
    homer2_sd, size(filtered_od, 2));
validate_dpf(dpf, wavelength_count);

require_dependency('hmrOD2Conc');
try
    dc = hmrOD2Conc(filtered_od, homer2_sd, dpf);
catch cause
    throw_external_failure('hmrOD2Conc', cause);
end

time_count = size(filtered_od, 1);
channel_count = size(channel_pairs, 1);
if ~isnumeric(dc) || ~isreal(dc) || isempty(dc) || ...
        any(~isfinite(dc(:))) || size(dc, 1) ~= time_count || ...
        size(dc, 2) ~= 3 || size(dc, 3) ~= channel_count
    error('homer2_preprocessing:InvalidOutput', ...
        'hmrOD2Conc returned an invalid concentration array.');
end

concentration = struct();
concentration.HbO = reshape(dc(:, 1, :), time_count, channel_count);
concentration.HbR = reshape(dc(:, 2, :), time_count, channel_count);
concentration.channel_pairs = channel_pairs;
end

function validate_od(filtered_od)
if ~isnumeric(filtered_od) || ~isreal(filtered_od) || ...
        isempty(filtered_od) || ~ismatrix(filtered_od) || ...
        any(~isfinite(filtered_od(:)))
    error('homer2_preprocessing:InvalidInput', ...
        ['filtered_od must be a nonempty, finite, real numeric ' ...
         'time-by-measurement matrix.']);
end
end

function [channel_pairs, wavelength_count] = validate_probe( ...
        homer2_sd, measurement_count)
required_fields = {'Lambda', 'MeasList', 'SrcPos', 'DetPos'};
if ~isstruct(homer2_sd) || ~isscalar(homer2_sd) || ...
        ~all(isfield(homer2_sd, required_fields))
    error('homer2_preprocessing:InvalidProbeMetadata', ...
        ['homer2_sd must be a scalar structure containing Lambda, ' ...
         'MeasList, SrcPos, and DetPos.']);
end

wavelengths = homer2_sd.Lambda;
if ~isnumeric(wavelengths) || ~isreal(wavelengths) || ...
        ~isvector(wavelengths) || isempty(wavelengths) || ...
        any(~isfinite(wavelengths(:))) || any(wavelengths(:) <= 0) || ...
        numel(wavelengths) < 2
    error('homer2_preprocessing:InvalidProbeMetadata', ...
        'Lambda must be a finite, positive, real numeric vector with at least two values.');
end
wavelength_count = numel(wavelengths);

measurement_list = homer2_sd.MeasList;
if ~isnumeric(measurement_list) || ~isreal(measurement_list) || ...
        ~ismatrix(measurement_list) || size(measurement_list, 2) < 4 || ...
        size(measurement_list, 1) ~= measurement_count || ...
        any(~isfinite(measurement_list(:)))
    error('homer2_preprocessing:InvalidProbeMetadata', ...
        ['MeasList must be a finite real numeric matrix with at least four ' ...
         'columns and one row per OD measurement.']);
end

source_indices = measurement_list(:, 1);
detector_indices = measurement_list(:, 2);
wavelength_indices = measurement_list(:, 4);
if any(~is_positive_integer(source_indices)) || ...
        any(~is_positive_integer(detector_indices)) || ...
        any(~is_positive_integer(wavelength_indices)) || ...
        any(wavelength_indices > wavelength_count)
    error('homer2_preprocessing:InvalidProbeMetadata', ...
        'MeasList source, detector, and wavelength indices must be valid positive integers.');
end

source_positions = homer2_sd.SrcPos;
detector_positions = homer2_sd.DetPos;
if ~is_position_matrix(source_positions) || ...
        ~is_position_matrix(detector_positions) || ...
        size(source_positions, 2) ~= size(detector_positions, 2) || ...
        any(source_indices > size(source_positions, 1)) || ...
        any(detector_indices > size(detector_positions, 1))
    error('homer2_preprocessing:InvalidProbeMetadata', ...
        'SrcPos and DetPos must be compatible finite position matrices covering all indices.');
end

validate_spatial_unit(homer2_sd);
validate_no_duplicate_definitions( ...
    source_indices, detector_indices, wavelength_indices);

anchor_rows = find(wavelength_indices == 1);
if isempty(anchor_rows)
    error('homer2_preprocessing:InvalidProbeMetadata', ...
        'Every channel must have exactly one wavelength-index-1 anchor.');
end
channel_pairs = measurement_list(anchor_rows, 1:2);
covered_rows = false(measurement_count, 1);

for channel_index = 1:size(channel_pairs, 1)
    source_index = channel_pairs(channel_index, 1);
    detector_index = channel_pairs(channel_index, 2);

    if channel_index > 1 && any(all( ...
            channel_pairs(1:channel_index-1, :) == ...
            channel_pairs(channel_index, :), 2))
        error('homer2_preprocessing:InvalidProbeMetadata', ...
            'Each channel must have exactly one wavelength-index-1 anchor.');
    end

    pair_rows = find(source_indices == source_index & ...
        detector_indices == detector_index);
    pair_wavelengths = wavelength_indices(pair_rows);
    if numel(pair_rows) ~= wavelength_count || ...
            ~isequal(sort(pair_wavelengths(:)).', 1:wavelength_count)
        error('homer2_preprocessing:InvalidProbeMetadata', ...
            'Every channel must contain exactly one measurement per wavelength.');
    end

    nonanchor_rows = find(source_indices == source_index & ...
        detector_indices == detector_index & wavelength_indices > 1);
    if ~isequal(wavelength_indices(nonanchor_rows).', 2:wavelength_count)
        error('homer2_preprocessing:InvalidProbeMetadata', ...
            ['Measurements after the wavelength-index-1 anchor must already ' ...
             'follow wavelength-index order.']);
    end

    distance = norm(source_positions(source_index, :) - ...
        detector_positions(detector_index, :));
    if ~isfinite(distance) || distance <= 0
        error('homer2_preprocessing:InvalidProbeMetadata', ...
            'Every channel must have a finite, positive source-detector distance.');
    end
    covered_rows(pair_rows) = true;
end

if ~all(covered_rows)
    error('homer2_preprocessing:InvalidProbeMetadata', ...
        'Every measurement must belong to a channel with one wavelength-index-1 anchor.');
end
end

function result = is_positive_integer(values)
result = isfinite(values) & values > 0 & values == fix(values);
end

function valid = is_position_matrix(value)
valid = isnumeric(value) && isreal(value) && ~isempty(value) && ...
    ismatrix(value) && size(value, 2) > 0 && all(isfinite(value(:)));
end

function validate_spatial_unit(homer2_sd)
if ~isfield(homer2_sd, 'SpatialUnit')
    return;
end
unit = homer2_sd.SpatialUnit;
if ischar(unit)
    valid_text = isrow(unit) && ~isempty(unit);
elseif isstring(unit)
    valid_text = isscalar(unit) && ~ismissing(unit) && strlength(unit) > 0;
else
    valid_text = false;
end
if ~valid_text || ~(strcmpi(unit, 'mm') || strcmpi(unit, 'cm'))
    error('homer2_preprocessing:InvalidProbeMetadata', ...
        'SpatialUnit, when present, must be scalar text equal to mm or cm.');
end
end

function validate_no_duplicate_definitions( ...
        source_indices, detector_indices, wavelength_indices)
measurement_count = numel(source_indices);
for first = 1:measurement_count-1
    duplicate = source_indices(first+1:end) == source_indices(first) & ...
        detector_indices(first+1:end) == detector_indices(first) & ...
        wavelength_indices(first+1:end) == wavelength_indices(first);
    if any(duplicate)
        error('homer2_preprocessing:InvalidProbeMetadata', ...
            'Duplicate source-detector-wavelength definitions are not permitted.');
    end
end
end

function validate_dpf(dpf, wavelength_count)
if ~isnumeric(dpf) || ~isreal(dpf) || ~isrow(dpf) || isempty(dpf) || ...
        numel(dpf) ~= wavelength_count || any(~isfinite(dpf(:))) || ...
        any(dpf(:) <= 0)
    error('homer2_preprocessing:InvalidParameter', ...
        'dpf must be a finite, positive real numeric row vector with one value per wavelength.');
end
end

function require_dependency(function_name)
if exist(function_name, 'file') == 0
    error('homer2_preprocessing:MissingDependency', ...
        'Required Homer2 function %s cannot be resolved.', function_name);
end
end

function throw_external_failure(function_name, cause)
wrapped = MException('homer2_preprocessing:ExternalCallFailed', ...
    'External Homer2 call to %s failed.', function_name);
wrapped = addCause(wrapped, cause);
throwAsCaller(wrapped);
end

function corrected_od = homer2_wavelet_correct_od(od, homer2_sd, iqr)
%HOMER2_WAVELET_CORRECT_OD Apply legacy Homer2 wavelet correction.
%   CORRECTED_OD = HOMER2_WAVELET_CORRECT_OD(OD, HOMER2_SD, IQR) forwards
%   finite real time-by-measurement optical density, the complete native SD
%   structure, and a nonnegative IQR parameter to hmrMotionCorrectWavelet.
%   The external stage is explicitly enabled. Output dimensions and
%   measurement order equal OD.

if nargin ~= 3
    error('homer2_preprocessing:InvalidInputCount', ...
        'homer2_wavelet_correct_od requires exactly three inputs.');
end
validate_od(od);
validate_probe(homer2_sd, size(od, 2));
if ~isnumeric(iqr) || ~isreal(iqr) || ~isscalar(iqr) || ...
        ~isfinite(iqr) || iqr < 0
    error('homer2_preprocessing:InvalidParameter', ...
        'iqr must be a finite, real, nonnegative numeric scalar.');
end

require_dependency('hmrMotionCorrectWavelet');
try
    corrected_od = hmrMotionCorrectWavelet(od, homer2_sd, iqr, 1);
catch cause
    throw_external_failure('hmrMotionCorrectWavelet', cause);
end

validate_matrix_output(corrected_od, size(od), ...
    'hmrMotionCorrectWavelet');
end

function validate_od(od)
if ~isnumeric(od) || ~isreal(od) || isempty(od) || ~ismatrix(od) || ...
        any(~isfinite(od(:)))
    error('homer2_preprocessing:InvalidInput', ...
        'od must be a nonempty, finite, real numeric time-by-measurement matrix.');
end
end

function validate_probe(homer2_sd, measurement_count)
if ~isstruct(homer2_sd) || ~isscalar(homer2_sd) || ...
        ~isfield(homer2_sd, 'MeasListAct')
    error('homer2_preprocessing:InvalidProbeMetadata', ...
        'homer2_sd must be a scalar structure containing MeasListAct.');
end
activity = homer2_sd.MeasListAct;
if ~(isnumeric(activity) || islogical(activity)) || ~isvector(activity) || ...
        isempty(activity) || any(~isfinite(activity(:))) || ...
        numel(activity) ~= measurement_count || ...
        any(activity(:) ~= 0 & activity(:) ~= 1)
    error('homer2_preprocessing:InvalidProbeMetadata', ...
        ['MeasListAct must be a finite binary numeric or logical vector ' ...
         'with one element per OD measurement column.']);
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

function validate_matrix_output(value, expected_size, function_name)
if ~isnumeric(value) || ~isreal(value) || isempty(value) || ...
        ~ismatrix(value) || any(~isfinite(value(:))) || ...
        ~isequal(size(value), expected_size)
    error('homer2_preprocessing:InvalidOutput', ...
        '%s returned an invalid or dimensionally incompatible output.', ...
        function_name);
end
end

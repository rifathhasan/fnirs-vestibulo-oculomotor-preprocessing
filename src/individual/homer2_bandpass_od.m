function filtered_od = homer2_bandpass_od( ...
        corrected_od, sampling_rate_hz, low_hz, high_hz)
%HOMER2_BANDPASS_OD Filter optical density using legacy Homer2.
%   FILTERED_OD = HOMER2_BANDPASS_OD(CORRECTED_OD, SAMPLING_RATE_HZ,
%   LOW_HZ, HIGH_HZ) calls hmrBandpassFilt exactly once and returns only its
%   first output. CORRECTED_OD and FILTERED_OD are finite real
%   time-by-measurement matrices with identical dimensions and ordering.

if nargin ~= 4
    error('homer2_preprocessing:InvalidInputCount', ...
        'homer2_bandpass_od requires exactly four inputs.');
end
if ~isnumeric(corrected_od) || ~isreal(corrected_od) || ...
        isempty(corrected_od) || ~ismatrix(corrected_od) || ...
        any(~isfinite(corrected_od(:)))
    error('homer2_preprocessing:InvalidInput', ...
        ['corrected_od must be a nonempty, finite, real numeric ' ...
         'time-by-measurement matrix.']);
end
if ~is_positive_finite_scalar(sampling_rate_hz) || ...
        ~is_positive_finite_scalar(low_hz) || ...
        ~is_positive_finite_scalar(high_hz) || ...
        low_hz >= high_hz || high_hz >= sampling_rate_hz / 2
    error('homer2_preprocessing:InvalidParameter', ...
        ['Require positive finite scalar parameters satisfying ' ...
         'low_hz < high_hz < sampling_rate_hz/2.']);
end

require_dependency('hmrBandpassFilt');
try
    filtered_od = hmrBandpassFilt( ...
        corrected_od, sampling_rate_hz, low_hz, high_hz);
catch cause
    throw_external_failure('hmrBandpassFilt', cause);
end

validate_matrix_output(filtered_od, size(corrected_od), ...
    'hmrBandpassFilt');
end

function valid = is_positive_finite_scalar(value)
valid = isnumeric(value) && isreal(value) && isscalar(value) && ...
    isfinite(value) && value > 0;
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

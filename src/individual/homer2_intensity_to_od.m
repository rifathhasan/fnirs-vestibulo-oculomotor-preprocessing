function od = homer2_intensity_to_od(intensity)
%HOMER2_INTENSITY_TO_OD Convert intensity using legacy Homer2.
%   OD = HOMER2_INTENSITY_TO_OD(INTENSITY) forwards a positive, finite,
%   real time-by-measurement intensity matrix unchanged to
%   hmrIntensity2OD. OD has the same dimensions and measurement order.

if nargin ~= 1
    error('homer2_preprocessing:InvalidInputCount', ...
        'homer2_intensity_to_od requires exactly one input.');
end
if ~isnumeric(intensity) || ~isreal(intensity) || isempty(intensity) || ...
        ~ismatrix(intensity) || any(~isfinite(intensity(:))) || ...
        any(intensity(:) <= 0)
    error('homer2_preprocessing:InvalidInput', ...
        ['intensity must be a nonempty, finite, real, strictly positive ' ...
         'numeric time-by-measurement matrix.']);
end

require_dependency('hmrIntensity2OD');
try
    od = hmrIntensity2OD(intensity);
catch cause
    throw_external_failure('hmrIntensity2OD', cause);
end

validate_matrix_output(od, size(intensity), 'hmrIntensity2OD');
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

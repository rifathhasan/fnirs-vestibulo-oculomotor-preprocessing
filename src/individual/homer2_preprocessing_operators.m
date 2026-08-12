function operators = homer2_preprocessing_operators(homer2_sd)
%HOMER2_PREPROCESSING_OPERATORS Create isolated Homer2 operation handles.
%   OPERATORS = HOMER2_PREPROCESSING_OPERATORS(HOMER2_SD) returns four
%   function handles for the legacy Homer2 numeric-array API. HOMER2_SD is
%   captured unchanged by the SD-dependent handles. Constructing OPERATORS
%   performs no preprocessing and does not require Homer2 to be on the path.

if nargin ~= 1
    error('homer2_preprocessing:InvalidInputCount', ...
        'homer2_preprocessing_operators requires exactly one input.');
end
if ~isstruct(homer2_sd) || ~isscalar(homer2_sd)
    error('homer2_preprocessing:InvalidProbeMetadata', ...
        'homer2_sd must be a scalar structure.');
end

operators = struct();
operators.intensity_to_od = @homer2_intensity_to_od;
operators.wavelet_correct_od = @(od, iqr) ...
    homer2_wavelet_correct_od(od, homer2_sd, iqr);
operators.bandpass_od = @(od, sampling_rate_hz, low_hz, high_hz) ...
    homer2_bandpass_od(od, sampling_rate_hz, low_hz, high_hz);
operators.od_to_concentration = @(od, dpf) ...
    homer2_od_to_concentration(od, homer2_sd, dpf);
end

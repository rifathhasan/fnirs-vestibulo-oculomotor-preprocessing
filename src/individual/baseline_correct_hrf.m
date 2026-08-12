function corrected = baseline_correct_hrf(hrf, time, baseline_window)
%BASELINE_CORRECT_HRF Baseline-correct a condition-averaged participant HRF.
%   CORRECTED = BASELINE_CORRECT_HRF(HRF, TIME, BASELINE_WINDOW) subtracts
%   each channel's baseline mean from every time sample in that channel.
%
%   Inputs:
%     HRF             - Numeric time-by-channel matrix containing a
%                       condition-averaged participant HRF. NaNs represent
%                       missing values; Inf values are not permitted.
%     TIME            - Numeric time-by-1 or 1-by-time vector, in seconds,
%                       with one finite, real, strictly increasing value per
%                       HRF row.
%     BASELINE_WINDOW - Two-element finite real vector [start_time end_time],
%                       in seconds. The recording must cover both endpoints.
%
%   Output:
%     CORRECTED       - Baseline-corrected time-by-channel matrix with the
%                       same dimensions as HRF.
%
%   Baseline samples include TIME values satisfying start_time <= TIME <=
%   end_time. The mean is calculated independently for each channel after
%   omitting NaNs. At least two sampled time points and at least two non-NaN
%   baseline values per channel are required. Original NaN positions are
%   preserved; values are never interpolated or imputed. This function does
%   not perform filtering, motion correction, averaging, outlier removal, or
%   other preprocessing.

if ~isnumeric(hrf) || ~ismatrix(hrf) || isempty(hrf) || ~isreal(hrf)
    error('baseline_correct_hrf:InvalidHRF', ...
        'hrf must be a nonempty, real, numeric 2-D time-by-channel matrix.');
end
if any(isinf(hrf(:)))
    error('baseline_correct_hrf:InfiniteHRF', ...
        'hrf must not contain Inf values.');
end
if ~isnumeric(time) || ~isvector(time) || isempty(time) || ~isreal(time) || ...
        any(~isfinite(time(:)))
    error('baseline_correct_hrf:InvalidTime', ...
        'time must be a nonempty, finite, real, numeric vector.');
end

time = time(:);
if numel(time) ~= size(hrf, 1)
    error('baseline_correct_hrf:TimeDimensionMismatch', ...
        'time must contain exactly one value per HRF row.');
end
if any(diff(time) <= 0)
    error('baseline_correct_hrf:NonIncreasingTime', ...
        'time must be strictly increasing with no duplicate values.');
end

if ~isnumeric(baseline_window) || ~isvector(baseline_window) || ...
        numel(baseline_window) ~= 2 || ~isreal(baseline_window) || ...
        any(~isfinite(baseline_window(:)))
    error('baseline_correct_hrf:InvalidBaselineWindow', ...
        'baseline_window must contain exactly two finite, real numeric values.');
end
baseline_window = baseline_window(:).';
if baseline_window(1) >= baseline_window(2)
    error('baseline_correct_hrf:InvalidBaselineWindow', ...
        'baseline_window start_time must be less than end_time.');
end
if min(time) > baseline_window(1) || max(time) < baseline_window(2)
    error('baseline_correct_hrf:IncompleteBaselineCoverage', ...
        'The recording must cover the complete requested baseline interval.');
end

baseline_mask = time >= baseline_window(1) & time <= baseline_window(2);
if nnz(baseline_mask) < 2
    error('baseline_correct_hrf:InsufficientBaselineSamples', ...
        'The baseline interval must contain at least two sampled time points.');
end

hrf_for_calculation = double(hrf);
baseline_values = hrf_for_calculation(baseline_mask, :);
baseline_means = zeros(1, size(hrf, 2));
for channel = 1:size(hrf, 2)
    usable = ~isnan(baseline_values(:, channel));
    if nnz(usable) < 2
        error('baseline_correct_hrf:InsufficientValidBaselineSamples', ...
            ['Each channel must contain at least two valid non-NaN ' ...
             'samples in the baseline interval.']);
    end
    baseline_means(channel) = mean(baseline_values(usable, channel));
end

corrected = bsxfun(@minus, hrf_for_calculation, baseline_means);
corrected(isnan(hrf)) = NaN;
if ~isequal(size(corrected), size(hrf))
    error('baseline_correct_hrf:OutputDimensionMismatch', ...
        'Output dimensions must equal input HRF dimensions.');
end
end

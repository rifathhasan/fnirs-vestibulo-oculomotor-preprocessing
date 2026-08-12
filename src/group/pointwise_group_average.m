function [group_mean, report] = pointwise_group_average(values, threshold_sd)
%POINTWISE_GROUP_AVERAGE Calculate a group mean after pointwise exclusion.
%   [GROUP_MEAN, REPORT] = POINTWISE_GROUP_AVERAGE(VALUES, THRESHOLD_SD)
%   applies one candidate-inclusive outlier-detection pass independently at
%   every time-by-channel point, then recalculates descriptive statistics
%   from the retained participant values.
%
%   Inputs:
%     VALUES       - Finite real numeric time-by-channel-by-participant
%                    array. At least two participant slices are required.
%                    Values are not modified, interpolated, or imputed.
%     THRESHOLD_SD - Positive finite real scalar multiplier for the initial
%                    across-participant sample standard deviation.
%
%   Outputs:
%     GROUP_MEAN - Time-by-channel arithmetic mean of retained values.
%                  A point with no retained values is NaN.
%     REPORT     - Scalar structure containing THRESHOLD_SD, INITIAL_MEAN,
%                  INITIAL_SD, FINAL_SD, OUTLIER_MASK, N_INCLUDED, and
%                  N_EXCLUDED. The mask's third dimension preserves input
%                  participant order.
%
%   Initial statistics include every candidate and use sample SD (N-1).
%   A value is excluded only when its absolute deviation is strictly greater
%   than THRESHOLD_SD times the initial SD. Detection is one-pass only.
%   Final sample SD is zero for one retained value and NaN for none.

if nargin ~= 2
    error('pointwise_group_average:InvalidInputCount', ...
        'pointwise_group_average requires exactly two inputs.');
end

if ~isnumeric(values) || ~isreal(values) || isempty(values) || ...
        ndims(values) > 3 || any(~isfinite(values(:)))
    error('pointwise_group_average:InvalidValues', ...
        ['values must be a nonempty, finite, real numeric ' ...
         'time-by-channel-by-participant array.']);
end
if size(values, 3) < 2
    error('pointwise_group_average:InsufficientParticipants', ...
        'At least two participant slices are required.');
end
if ~isnumeric(threshold_sd) || ~isreal(threshold_sd) || ...
        ~isscalar(threshold_sd) || ~isfinite(threshold_sd) || ...
        threshold_sd <= 0
    error('pointwise_group_average:InvalidThreshold', ...
        'threshold_sd must be a positive finite real numeric scalar.');
end

initial_mean = mean(values, 3);
initial_sd = std(values, 0, 3);
deviation = abs(values - initial_mean);
outlier_mask = deviation > threshold_sd * initial_sd;
included_mask = ~outlier_mask;

n_excluded = sum(outlier_mask, 3);
n_included = sum(included_mask, 3);
included_sum = sum(values .* included_mask, 3);
group_mean = included_sum ./ n_included;
group_mean(n_included == 0) = NaN;

final_sd = NaN(size(initial_mean));
for channel_index = 1:size(values, 2)
    for time_index = 1:size(values, 1)
        point_values = reshape(values(time_index, channel_index, :), [], 1);
        point_included = reshape( ...
            included_mask(time_index, channel_index, :), [], 1);
        retained = point_values(point_included);
        if numel(retained) == 1
            final_sd(time_index, channel_index) = 0;
        elseif numel(retained) >= 2
            final_sd(time_index, channel_index) = std(retained, 0);
        end
    end
end

report = struct('threshold_sd', threshold_sd, ...
    'initial_mean', initial_mean, 'initial_sd', initial_sd, ...
    'final_sd', final_sd, 'outlier_mask', outlier_mask, ...
    'n_included', n_included, 'n_excluded', n_excluded);
end

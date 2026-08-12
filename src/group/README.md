# Group Processing

`pointwise_group_average` applies pointwise exclusion to a `time x channel x participant` array and returns the final mean with quality control fields. `aggregate_participant_hrfs` checks participant response compatibility, aligns exact condition names, preserves channel order, and calls the pointwise function separately for HbO and HbR.

Inputs must contain finite participant condition responses with matching time vectors, dimensions, and `channel_pairs` order.

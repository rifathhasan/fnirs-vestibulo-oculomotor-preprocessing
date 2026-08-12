% LOCAL_PATHS.EXAMPLE Template for machine-local path configuration.
%
% Copy this file to local_paths.m and customize the copied file. The copied
% file is ignored by Git. Keep participant locations and machine-specific
% absolute paths out of version-controlled files.

project_root = fileparts(fileparts(mfilename('fullpath')));

local_paths = struct();
local_paths.data_root = fullfile(project_root, 'local_data');
local_paths.output_root = fullfile(project_root, 'outputs');

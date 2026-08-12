function [recording, adapter_context] = load_nirs_recording(file_path)
%LOAD_NIRS_RECORDING Load and translate a Homer MAT-format .nirs file.
%   RECORDING = LOAD_NIRS_RECORDING(FILE_PATH) loads the native top-level
%   fields from FILE_PATH and passes the resulting scalar structure to
%   translate_nirs_structure. FILE_PATH is a scalar character vector or
%   nonmissing scalar string naming an existing .nirs file.
%   [RECORDING, ADAPTER_CONTEXT] additionally returns the unchanged native
%   Homer2 SD structure as format-specific adapter metadata.
%
%   The function performs file I/O and format translation only. It does not
%   validate acquisition expectations, alter events, or process signals.

if nargin ~= 1
    error('load_nirs_recording:InvalidInputCount', ...
        'load_nirs_recording requires exactly one input.');
end

file_path = validate_file_path(file_path);
if ~isfile(file_path)
    error('load_nirs_recording:FileNotFound', ...
        'The requested .nirs file does not exist.');
end

[~, ~, extension] = fileparts(file_path);
if ~strcmpi(extension, '.nirs')
    error('load_nirs_recording:InvalidFilePath', ...
        'file_path must identify a file with a .nirs extension.');
end

try
    native = load(file_path, '-mat');
catch
    error('load_nirs_recording:UnreadableFile', ...
        'The .nirs file could not be read as a MAT-format file.');
end

if nargout > 1
    [recording, adapter_context] = translate_nirs_structure(native);
else
    recording = translate_nirs_structure(native);
end
end

function file_path = validate_file_path(file_path)
if ischar(file_path)
    valid = isrow(file_path) && ~isempty(strtrim(file_path));
elseif isstring(file_path)
    valid = isscalar(file_path) && ~ismissing(file_path) && ...
        strlength(strtrim(file_path)) > 0;
    if valid
        file_path = char(file_path);
    end
else
    valid = false;
end

if ~valid
    error('load_nirs_recording:InvalidFilePath', ...
        ['file_path must be a nonempty scalar character vector or ' ...
         'nonmissing scalar string.']);
end
end

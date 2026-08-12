function [recording, adapter_context] = load_fnirs_recording(file_path)
%LOAD_FNIRS_RECORDING Load a supported raw fNIRS file representation.
%   RECORDING = LOAD_FNIRS_RECORDING(FILE_PATH) dispatches a raw recording
%   file to a format-specific adapter. FILE_PATH is a scalar character
%   vector or nonmissing scalar string. The returned RECORDING is the
%   standardized in-memory structure consumed by validate_raw_recording.
%   [RECORDING, ADAPTER_CONTEXT] additionally returns format-specific
%   metadata needed by later external-tool adapters. For .nirs files,
%   ADAPTER_CONTEXT preserves the native Homer2 SD structure unchanged.
%
%   This implementation supports MAT-format Homer .nirs files only. It
%   translates file structure and metadata without performing validation of
%   scientific acquisition expectations or any signal processing.

if nargin ~= 1
    error('load_fnirs_recording:InvalidInputCount', ...
        'load_fnirs_recording requires exactly one input.');
end

file_path = validate_file_path(file_path);
if ~isfile(file_path)
    error('load_fnirs_recording:FileNotFound', ...
        'The requested fNIRS recording file does not exist.');
end

[~, ~, extension] = fileparts(file_path);
if ~strcmpi(extension, '.nirs')
    error('load_fnirs_recording:UnsupportedFileType', ...
        'Only .nirs files are supported by this loader.');
end

try
    if nargout > 1
        [recording, adapter_context] = load_nirs_recording(file_path);
    else
        recording = load_nirs_recording(file_path);
    end
catch exception
    if strcmp(exception.identifier, 'load_nirs_recording:UnreadableFile')
        error('load_fnirs_recording:UnreadableFile', ...
            'The .nirs file could not be read as a MAT-format file.');
    end
    rethrow(exception);
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
    error('load_fnirs_recording:InvalidFilePath', ...
        ['file_path must be a nonempty scalar character vector or ' ...
         'nonmissing scalar string.']);
end
end

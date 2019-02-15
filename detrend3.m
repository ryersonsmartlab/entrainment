%DETREND3  Wrapper on detrend for 3D EEGLAB data matrices.
%
% USAGE
%   data = detrend3(data)
%   data = detrend3(data, varargin)
%
% INPUT
%   data          = [numeric] A channels-by-time-by-trials array of data.
%
%   varargin      = Other arguments are passed to detrend.
%                   See help detrend.

function data = detrend3(data, varargin)

if size(size(data)) ~= 3, error('Data must be 3D.'), end

% change data to time-by-channels-by-trials: detrend operates columnwise on
%   matrices, and there is no switch to tell it to operate on rows instead,
%   so we have to manually transpose.
data = permute(data, [2 1 3]);

% loop trials and detrend all channels
for trial = 1:length(data, 3)
    data(:, :, trial) = detrend(data(:, :, trial), varargin);
end

% change back to channels-by-time-by-trials
data = permute(data, [2 1 3]);

end

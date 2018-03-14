%% en_eeg_entrainment
%   Calculate entrainment of comps in a brain region. Saves topo and dip
%   plots and writes data to a csv file.
%
% Usage:
%   T = en_eeg_entrainment(EEG)
%   T = en_eeg_entrainment(EEG, 'param', value, etc.)
%   [T, fftdata, freqs] = en_eeg_entrainment(...)
%
% Input:
%   EEG = [struct|numeric] EEGLAB struct with ICA and dipole information,
%       or ID number to load from en_getpath('eeg').
%
%   'region' = [string|numeric] Usually this will be 'pmc' or 'aud' to
%       select Brodmann areas 6 or [22 41 42] respectively. Can also be
%       numeric to specify other Broadmann areas.
%
%   'stim' = ['sync'|'mir']
%
%   'trig' = ['eeg'|'tapping']
%
%   'rv' = [numeric between 0 and 1] Residual variance threshold for
%       selecting components.
%
%   'width' = [numeric (int)] Number of bins on either side of center bin
%       to include when selecting the max peak for a given frequency.
%
% Output:
%   T = [table] Data from logfile, stiminfo, and the entrainment analysis
%       in a single MATLAB table. This table is also written as a csv to
%       en_getpath('entrainment').
%
%   fftdata = [numeric] The fft data matrix (comps x frequency x trial).
%
%   freqs = [numeric] The corresponding frequency vector.

% input can be a preprocessed EEG struct (with ICA and dipfit)
%   or a numeric ID number

function [T, fftdata, freqs] = en_eeg_entrainment(EEG, varargin)

% defaults
region = 'pmc'; % pmc = 6, aud = [22 41 42]
stimType = 'sync';
trigType = 'eeg';
rv = 0.15;
nfft = 2^16; % 2^16 = bin width of 0.0078 Hz
binwidth = 1; % number of bins on either side of tempo bin
% tempos are 0.1 Hz apart, so half-width max is 0.05
% binwidth = 1 means 3 bins are 0.0078 * 3 = 0.0234 Hz wide
% binwidth = 2 means 5 bins are 0.0078 * 5 = 0.0391 Hz wide
% binwidth = 3 means 7 bins are 0.0078 * 7 = 0.0546 Hz wide -- this is too
%   wide; tempos will run into one another

% user-defined
for i = 1:2:length(varargin)
    val = varargin{i+1};
    switch lower(varargin{i})
        case 'region',              if ~isempty(val), region = val; end
        case {'stim', 'stimtype'},  if ~isempty(val), stimType = val; end
        case {'trig', 'trigtype'},  if ~isempty(val), trigType = val; end
        case 'rv',                  if ~isempty(val), rv = val; end
        case {'width', 'binwidth'}, if ~isempty(val), binwidth = val; end
    end
end

% get region and regionStr
if ischar(region)
    regionStr = region;
    switch lower(regionStr)
        case 'pmc', region = 6;
        case 'aud', region = [22 41 42];
        otherwise, error('Invalid string for region input.')
    end
elseif isnumeric(region)
    if region == 6,                             regionStr = 'pmc';
    elseif all(ismember(region, [22 41 42])),   regionStr = 'aud';
    else,                                       regionStr = 'other';
    end
end

% get preprocessed EEG struct
if isnumeric(EEG)
    EEG = en_load('eeg', EEG);
elseif ~isstruct(EEG)
    error('Input must be an EEG struct or an ID number.')
end

% filter comps by region, rv, dipolarity
d = en_load('diary', str2num(EEG.setname)); % EEG.setname should be the ID
comps = select_comps(EEG, rv, region, d.dipolar_comps{1});
dtplot(EEG, comps, en_getpath([regionStr, 'comps'])); % save plots of good ICs

[fftdata, freqs] = getfft3(EEG.data(comps, :, :), ...
    EEG.srate, ...
    'spectrum',     'amplitude', ...
    'nfft',         nfft, ...
    'detrend',      false, ...
    'wintype',      'hanning', ...
    'ramp',         [], ...
    'dim',          2); % should the the time dimension

[fftdata, freqs] = noisefloor3(fftdata, [2 2], freqs);

% get tempos
L = en_load('logfile', EEG.setname); % setname should be id
L = L(L.stimType==stimType & L.trigType==trigType, :);
S = en_load('stiminfo', L.portcode);
if all(L.portcode == S.portcode)
    S.portcode = [];
    S.stimType = [];
    T = [L, S];
end

% get values of each bin
en = nan(size(fftdata, 1), length(S.tempo));
for i = 1:length(en) % loop trials
    en(:, i) = getbins3(fftdata(:, :, i), freqs, S.tempo(i), ...
    'width', binwidth, ...
    'func',  'max');
end
[en, comps_ind] = max(en, [], 1); % take max of all comps
comp = comps(comps_ind);

% make them column vectors
T.id = repmat(EEG.setname, length(en), 1);
T.comp = transpose(comp);
T.en = transpose(en);
T.Properties.VariableNames{end} = regionStr;

writetable(T, fullfile(en_getpath('entrainment'), [EEG.setname, '_', regionStr, '.csv']))

end
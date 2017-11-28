function main(test)

if nargin < 1, test = false; end

% this is used to tag logfiles and datafiles for matching later
currentTime = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
address = hex2dec('d050'); % for eeg port codes using io64.mexw64

% define files and folders
logFolder = 'logfiles';
stimFolder = '../stimuli';
makeSureFoldersExist(logFolder, stimFolder)
logfileHeaders = {'id', 'stimType', 'trigType', 'trial', 'filename', 'move', 'pleasure', 'filepath', 'timestamp'};

% try/catch block around everything so we can exit graceful (i.e., close all files)
try

    % prepare
    ioObj = io64(); % initalize eeg port codes
    ioObj_status = io64(ioObj);
    if ioObj_status ~= 0
        disp('inp/outp installation failed!')
    end
    [id, stimType, trigType] = promptForTaskInfo(test); % id is a string
    [trialList, startTrial, logfile_fid] = getTrialList(logFolder, ...
        logfileHeaders, stimFolder, stimType, trigType, currentTime);

    % loop trials
    nTrials = length(trialList);
    for trial = startTrial:length(trialList)
        stimfile = trialList{trial};

        clc
        fprintf('Trial %i / %i\n', trial, nTrials)
        [move, pleasure] = playTrial(stimfile, stimType, trigType, ioObj, address);

        logResponse(logfile_fid, id, stimType, trigType, trial, stimfile, move, pleasure);

    end

catch err
    fprintf('\n*** WARNING ***\n')
    fprintf('There was problem running the task (error below).\n')
    fprintf('Attempting to close files first... ')
    fclose('all');
    fprintf('Done.\n')
    rethrow(err)

end

fclose('all');
end % end function

function logResponse(logfile_fid, id, stimType, trigType, trial, fname, move, pleasure)
[pathstr, name, ext] = fileparts(fname);
name = [name, ext];
timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
data = {id, stimType, trigType, trial, name, move, pleasure, pathstr, timestamp};
formatSpec = '%s,%s,%s,%i,%s,%i,%i,%s,%s\n';
fprintf(logfile_fid, formatSpec, data{:});
end

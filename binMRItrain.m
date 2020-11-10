function trial = binMRItrain(subID,sessID,runID)
% function [subject,task] = binMRI(subID,sessID,runID)
% Brain ImageNet fMRI experiment stimulus procedure
% subID, subjet ID, integer[1-20] 
% sessID, session ID, integer [1-4]
% runID, run ID, integer [1-10] 
% clc;clear;
%% Arguments
% if nargin < 3, subID = 1; end
% if nargin < 2, sessID = 1; end
% if nargin < 1, runID = 1; end

%% Check subject information
% Check subject id
if ~ismember(subID, 1:20)
    warning ('subID is a integer within [1:20]!');
end

% Check session id
if ~ismember(sessID, 1:4)
    warning ('sessID is a integer within [1:4]!');
end

% Check run id
if ~ismember(runID, 1:10)
    warning ('runID is a integer within [1:10]!');
end

%% Dir setting
workDir = 'D:\fMRI\BrainImageNet\stim';
stimDir = fullfile(workDir,'images');
designDir = fullfile(workDir,'designMatrix');
dataDir = fullfile(workDir,'data');
if ~exist(dataDir,'dir')
    mkdir(dataDir)
end

%% Prepare params
imgAngle = 12;
fixOuterAngle = 0.3;
fixInnerAngle = 0.2;
readyDotColor = [255 0 0];
bkgColor = [128 128 128];
% compute image pixel
pixelPerMilimeterHor = 1024/390;
pixelPerMilimeterVer = 768/295;
imgPixelHor = pixelPerMilimeterHor * (2 * 1000 * tan(imgAngle/180*pi/2));
imgPixelVer = pixelPerMilimeterVer * (2 * 1000 * tan(imgAngle/180*pi/2));
fixOuterSize = pixelPerMilimeterHor * (2 * 1000 * tan(fixOuterAngle/180*pi/2));
fixInnerSize = pixelPerMilimeterHor * (2 * 1000 * tan(fixInnerAngle/180*pi/2));

%% Response keys setting
PsychDefaultSetup(2);% Setup PTB to 'featureLevel' of 2
KbName('UnifyKeyNames'); % For cross-platform compatibility of keynaming
startKey = KbName('s');
escKey = KbName('ESCAPE');
likeKey = KbName('1!'); % Left hand:1!,2@
disLikeKey = KbName('3#'); % Right hand: 3#,4$ 

%% Screen setting
Screen('Preference', 'SkipSyncTests', 2);
Screen('Preference','VisualDebugLevel',4);
Screen('Preference','SuppressAllWarnings',1);
screenNumber = max(Screen('Screens'));% Set the screen to the secondary monitor
[wptr, rect] = Screen('OpenWindow', screenNumber, bkgColor);
[xCenter, yCenter] = RectCenter(rect);% the centre coordinate of the wptr in pixels
HideCursor;

%% Create instruction texture
% Makes instruction texture
picsFolderName = 'instruction';
imgStart = sprintf('%s/%s', picsFolderName, 'instructionStartTrain.jpg');
imgEnd = sprintf('%s/%s', picsFolderName, 'instructionBye.jpg');
startTexture = Screen('MakeTexture', wptr, imread(imgStart));
endTexture = Screen('MakeTexture', wptr, imread(imgEnd));

%% Load design matrix
load(fullfile(designDir,'BIN.mat'));
sess = 4*(subID-1)+ sessID;

% par for this run
sessPar = squeeze(BIN.paradigmClass(:,sess,:));
classOrder = sessPar(:,2);
sessStim = BIN.stimulus(classOrder,sess);
sessPar = reshape(sessPar,[100,10,3]);
sessStim = reshape(sessStim,[100,10]);
runStim = sessStim(:,runID);

% Image for this run
imgDir = reshape(BIN.classID(classOrder), [100,10]);
runImgDir = imgDir(:,runID);

% Collect trial info for this run 
nStim = size(runStim, 1);
trial = zeros(nStim, 6); % [onset, class, dur, key, rt]
trial(:,1:3) = squeeze(sessPar(:,runID,:)); % % [onset, class, dur]

%% Make stimuli texture
nStim = size(runStim, 1);
stimTexture = zeros(nStim,1);
for t = 1:nStim
    imgFile = fullfile(stimDir, runImgDir, runStim{t});
    img = imread(imgFile{t});
    img = imresize(img, [imgPixelHor imgPixelVer]);
    stimTexture(t) = Screen('MakeTexture', wptr, img);
end

%% Show instruction
Screen('DrawTexture', wptr, startTexture);
Screen('Flip', wptr);
% Wait ready signal from subject
while KbCheck(); end
while true
    [keyIsDown,~,keyCode] = KbCheck();
    if keyIsDown && keyCode(likeKey), break;
    end
end

Screen('DrawDots', wptr, [xCenter,yCenter], fixOuterSize, readyDotColor, [], 2);
Screen('Flip', wptr);

% Wait trigger(S key) to begin the test
while KbCheck(); end
while true
    [keyIsDown,~,keyCode] = KbCheck();
    if keyIsDown && keyCode(startKey), break;
    elseif keyIsDown && keyCode(escKey), sca; return;
    end
end

%% Run experiment
flipInterval = Screen('GetFlipInterval', wptr);% get dur of frame
onDur = 2 - 0.5*flipInterval; % on duration for a stimulus
offDur = 2; % off duration for a stimulus
runDur = 476; % duration for a run
beginDur = 16; % beigining fixation duration
endDur = 16; % ending fixation duration
fixOuterColor = [0 0 0]; % color of fixation circular ring
fixInnerColor = [255 255 255]; % color of fixation circular point
tEnd = [trial(2:end, 1);runDur]; % make sequence of tEnd

% Show begining fixation
Screen('DrawDots', wptr, [xCenter,yCenter], fixOuterSize, fixOuterColor, [], 2);
Screen('DrawDots', wptr, [xCenter,yCenter], fixInnerSize, fixInnerColor , [], 2);
Screen('Flip',wptr);
WaitSecs(beginDur);

tStart = GetSecs;
% Show stimulus
for t = 1:nStim
    % Show stimulus with fixation
    Screen('DrawTexture', wptr, stimTexture(t));
    Screen('DrawDots', wptr, [xCenter,yCenter], fixOuterSize, fixOuterColor, [], 2);
    Screen('DrawDots', wptr, [xCenter,yCenter], fixInnerSize, fixInnerColor , [], 2);
    tStim = Screen('Flip',wptr);
    trial(t, 6) = tStim - tStart;
    
    % Show begining fixation
    Screen('DrawDots', wptr, [xCenter,yCenter], fixOuterSize, fixOuterColor, [], 2);
    Screen('DrawDots', wptr, [xCenter,yCenter], fixInnerSize, fixInnerColor , [], 2);
    tFix = Screen('Flip', wptr, tStim + onDur);
    
    while KbCheck(), end % empty the key buffer
    while GetSecs - tFix < offDur
        [keyIsDown, tKey, keyCode] = KbCheck();       
        if keyIsDown
            if keyCode(escKey), sca; return;
            elseif keyCode(likeKey),   key = 1;
            elseif keyCode(disLikeKey), key = -1;
            end
            rt = tKey - tFix; % reaction time
            trial(t, 4:5) = [key,rt];
            break;
        end
    end
    
    % wait until tEnd
    while GetSecs - tStart < tEnd(t)
        [~, ~, keyCode] = KbCheck();
        if keyCode(escKey), sca; return; end
    end    
end

% Wait ending fixation
WaitSecs(endDur);

% Show end instruction
Screen('DrawTexture', wptr, endTexture);
Screen('Flip', wptr);
WaitSecs(2);

% show cursor and close all
ShowCursor;
Screen('CloseAll');

%% Save data for this run
subDir = fullfile(dataDir,sprintf('sub%02d', subID));
if ~exist(subDir,'dir')
    mkdir(subDir)
end
sessDir = fullfile(subDir,sprintf('sess%02d', sessID));
if ~exist(sessDir,'dir')
    mkdir(sessDir)
end
fileName = fullfile(sessDir, ...
    sprintf('sub%02d_sess%02d_run%02d.mat',subID,sessID, runID));
fprintf('Data were saved to: %s\n',fileName);
save(fileName,'trial');


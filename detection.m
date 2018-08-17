%Program: Epileptiform Activity Detector 
%Author: Michael Chang (michael.chang@live.ca), Fred Chen and Liam Long; 
%Copyright (c) 2018, Valiante Lab
%Version 2.0

%% Clear All
close all
clear all
clc


%% GUI to set thresholds
%Settings, request for user input on threshold
titleInput = 'Specify Detection Thresholds';
prompt1 = 'Epileptiform Spike Threshold: average + (6 x Sigma)';
prompt2 = 'Artifact Threshold: average + (100 x Sigma) ';
prompt3 = 'Figure: Yes (1) or No (0)'

prompt = {prompt1, prompt2, prompt3};
dims = [1 70];
definput = {'6', '100', '0'};
opts = 'on';
threshold_multiple = inputdlg(prompt,titleInput,dims,definput, opts);

%setting on distance between spikes, hard coded
distanceSpike = 1;  %distance between spikes (seconds)
distanceArtifact = 0.6; %distance between artifacts (seconds)

%% Load .abf and excel data
    [FileName,PathName] = uigetfile ('*.abf','pick .abf file', 'C:\Users\User\OneDrive - University of Toronto\3) Manuscript III (Nature)\Section 2\Control Data\1) Control (VGAT-ChR2, light-triggered)\1) abf files');%Choose abf file
    [x,samplingInterval,metadata]=abfload([PathName FileName]); %Load the file name with x holding the channel data(10,000 sampling frequency) -> Convert index to time value by dividing 10k
                                                                                         
%% create time vector
frequency = 1000000/samplingInterval; %Hz. si is the sampling interval in microseconds from the metadata
t = (0:(length(x)- 1))/frequency;
t = t';

%% Seperate signals from .abf files
LFP = x(:,1); 
LED = x(:,2); 

%% normalize the LFP data
LFP_normalized = LFP - LFP(1);

%% Find Light pulse
[P] = pulse_seq(LED);

%% Data Processing 
%Bandpass butter filter [1 - 100 Hz]
[b,a] = butter(2, [[1 100]/(frequency/2)], 'bandpass');
LFP_normalizedFiltered = filtfilt (b,a,LFP_normalized);

%Absolute value of the filtered data 
AbsLFP_normalizedFiltered = abs(LFP_normalizedFiltered);

%Derivative of the filtered data (absolute value)
DiffLFP_normalizedFiltered = abs(diff(LFP_normalizedFiltered));

%Find the quantiles using function quartilesStat
[mx, Q] = quartilesStat(DiffLFP_normalizedFiltered);

%Average
avg = mean(DiffLFP_normalizedFiltered);

%Std Dev
sigma = std(DiffLFP_normalizedFiltered);

%% Find prominient, distinct spikes in Derivative of filtered LFP (1st search)
%[pks_spike, locs_spike, w] = findpeaks (DiffLFP_normalizedFiltered, 'MinPeakHeight', Q(1)*str2num(threshold_multiple{3}), 'MinPeakDistance', 10000);
%
% %% Find prominient, distinct spikes in (absolute) filtered LFP (2nd search)
% [pks_spike, locs_spike] = findpeaks (AbsLFP_normalizedFiltered, 'MinPeakHeight', Q(3)*1000, 'MinPeakDistance', 1000); 

%% Detect potential events (epileptiform/artifacts) | Derivative Values
[epileptiformLocation, artifacts, locs_spike_1st] = detectEvents (DiffLFP_normalizedFiltered, frequency);

%testing for artifact location
%[artifacts_1st, locs_artifact_1st] = findArtifact(DiffLFP_normalizedFiltered);

% %testing finding artifact
% [pks_artifact, locs_artifact, w_artifact] = findpeaks (DiffLFP_normalizedFiltered, 'MinPeakHeight', Q(3)*120, 'MinPeakDistance', 6000); 


%remove potential events
for i = 1:size(epileptiformLocation,1)
AbsLFP_normalizedFiltered (epileptiformLocation (i,1):epileptiformLocation (i,2)) = [-1];
end

%remove artifacts
for i = 1:size(artifacts,1)
AbsLFP_normalizedFiltered (artifacts(i,1):artifacts(i,2)) = [-1];
end

%Isolate baseline recording
AbsLFP_normalizedFiltered (AbsLFP_normalizedFiltered == -1) = [];
AbsLFP_normalizedFilteredBaseline = AbsLFP_normalizedFiltered; %Rename

%Characterize baseline features from absolute value of the filtered data 
avg = mean(AbsLFP_normalizedFilteredBaseline); %Average
sigma = std(AbsLFP_normalizedFilteredBaseline); %Standard Deviation

%test figure
%Absolute value of the filtered data 
AbsLFP_normalizedFiltered = abs(LFP_normalizedFiltered);

figure; 
subplot (2,1,1)
plot(AbsLFP_normalizedFiltered);

subplot (2,1,2)
plot(AbsLFP_normalizedFilteredBaseline);

%% Detect events (epileptiform/artifacts) | Absolute Values
%Detect events
[epileptiformLocation, artifacts, locs_spike_2nd] = detectEvents (AbsLFP_normalizedFiltered, frequency, avg+(str2num(threshold_multiple{1})*sigma), distanceSpike*frequency, avg+(str2num(threshold_multiple{2})*sigma), distanceArtifact*frequency);

%testing for artifact location
%[artifacts_2nd, locs_artifact_2nd] = findArtifact(AbsLFP_normalizedFiltered, str2num(threshold_multiple{2}), sigma, avg, 6000);

% %testing finding artifact
% [pks_artifact, locs_artifact, w_artifact_abs] = findpeaks (AbsLFP_normalizedFiltered, 'MinPeakHeight', Q(3)*120, 'MinPeakDistance', 6000); 


%Find the quantiles using function quartilesStat
[mx, Q] = quartilesStat(AbsLFP_normalizedFilteredBaseline);

%Average
avg = mean(AbsLFP_normalizedFilteredBaseline);

%Std Dev
sigma_baseline = std(AbsLFP_normalizedFilteredBaseline);

%Std Dev
sigma_original = std(AbsLFP_normalizedFiltered);

%test, minimum threshold height for artifact
 minPeakHeight = (Q(3)*40)*3; 

%% Finding event time 
%Onset times (s)
onsetTimes = epileptiformLocation(:,1)/frequency; %frequency is your sampling rate

%Offset Times (s)
offsetTimes = epileptiformLocation(:,2)/frequency; 

%Duration of Epileptiform event 
duration = offsetTimes-onsetTimes;

%putting it all into an array 
epileptiform = [onsetTimes, offsetTimes, duration];

%% Identify light-triggered Events
%Find light-triggered spikes 
triggeredSpikes = findTriggeredEvents(AbsLFP_normalizedFiltered, LED);

%Preallocate
epileptiform(:,4)= 0;

%Find light-triggered events 
for i=1:size(epileptiform,1) 
    %use the "ismember" function 
    epileptiform(i,4)=ismember (epileptiformLocation(i,1), triggeredSpikes);
end

%Store light-triggered events (s)
triggeredEvents = epileptiform(epileptiform(:,4)>0, 1);

%% Classifier
SLE = epileptiform(epileptiform(:,3)>=10,:);
IIS = epileptiform(epileptiform(:,3)<10,:);

%% plot graph of normalized  data 

if str2num(threshold_multiple{3}) == 1

figHandle = figure;
set(gcf,'NumberTitle','off', 'color', 'w'); %don't show the figure number
set(gcf,'Name', sprintf ('Overview of %s', FileName)); %select the name you want
set(gcf, 'Position', get(0, 'Screensize'));

lightpulse = LED > 1;

subplot (3,1,1)
reduce_plot (t, LFP_normalized, 'k');
hold on
reduce_plot (t, lightpulse - 2);

%plot artifacts (red), found in 2nd search
for i = 1:numel(artifacts(:,1)) 
    reduce_plot (t(artifacts(i,1):artifacts(i,2)), LFP_normalized(artifacts(i,1):artifacts(i,2)), 'r');
end

%plot onset markers
for i=1:numel(epileptiform(:,1))
reduce_plot ((onsetTimes(i)), (LFP_normalized(epileptiformLocation(i))), 'o');
end

%plot offset markers
for i=1:numel(epileptiform(:,2))
reduce_plot ((offsetTimes(i)), (LFP_normalized(epileptiformLocation(i,2))), 'x');
end

title (sprintf ('Overview of LFP (10000 points/s), %s', FileName));
ylabel ('LFP (mV)');
xlabel ('Time (s)');

subplot (3,1,2) 
reduce_plot (t, AbsLFP_normalizedFiltered, 'b');
hold on
reduce_plot (t, lightpulse - 1);

%plot spikes (will work, with error message; index with artifact removed)
for i=1:size(locs_spike_2nd,1)
plot (t(locs_spike_2nd(i,1)), (DiffLFP_normalizedFiltered(locs_spike_2nd(i,1))), 'x')
end

title ('Overview of filtered LFP (bandpass: 1 to 100 Hz)');
ylabel ('LFP (mV)');
xlabel ('Time (s)');

subplot (3,1,3) 
reduce_plot (t(1:end-1), DiffLFP_normalizedFiltered, 'g');
hold on

% %plot onset markers
% for i=1:numel(locs_onset)
% plot (t(locs_spike(locs_onset(i))), (pks_spike(locs_onset(i))), 'o')
% end
 
%plot spikes 
for i=1:size(locs_spike_1st,1)
plot (t(locs_spike_1st(i,1)), (DiffLFP_normalizedFiltered(locs_spike_1st(i,1))), 'x')
end

% %plot artifacts, found in the 1st search
% for i=1:size(locs_artifact_1st(: ,1))
% plot (t(locs_artifact_1st(i,1)), (DiffLFP_normalizedFiltered(locs_artifact_1st(i,1))), 'o', 'MarkerSize', 12)
% end

% %plot offset markers
% for i=1:numel(locs_onset)
% plot ((offsetTimes(i)), (pks_spike(locs_onset(i))), 'x')
% end

title ('Peaks (o) in Derivative of filtered LFP');
ylabel ('Derivative (mV)');
xlabel ('Time (s)');

saveas(figHandle,sprintf('%s.png', FileName), 'png');

else
end


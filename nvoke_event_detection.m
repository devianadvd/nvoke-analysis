function [ROIdata_peakevent] = nvoke_event_detection(ROIdata, varargin)
%nvoke_event_detection 
% smooth data and find out peaks
% need structure array generated by "ROIinfo2matlab.m"
% nvoke_event_detection(ROIdata, plot_traces, subplot_roi, pause_step, lowpass_fpass)
% Input:
%		- 1. ROIdata
% 		- 2. plot_traces: 1-plot, 2-plot and save
%		- 3. subplot_roi: 1-5x2 rois in 1 figure, 2-2x1 rois in 1 figure
% 		- 4. pause_step: 1-pause after ploting every figure, 0-no pause
%		- 5. lowpass_fpass: lowpassfilter default passband is 1
%   Detailed explanation goes here
%
% nvoke_event_detection(ROIdata,1, 1)

if ispc
	figfolder_default = 'G:\Workspace\Inscopix_Seagate\Analysis\IO_GCaMP-IO_ChrimsonR-CN_ventral\peaks';
elseif isunix
	figfolder_default = '/home/guoda/Documents/Workspace/Analysis/nVoke/Ventral_approach/processed mat files/peaks';
end
lowpass_fpass = 10;

if nargin == 1 % ROIdata
	plot_traces = 0;
	pause_step = 0;
elseif nargin == 2 % ROIdata, plot_traces
	plot_traces = varargin{1};
	if plot_traces == 1 || 2
		pause_step = 1;
		subplot_roi = 1; % mode-1: 5x2 rois in 1 figure
	else
		pause_step = 0;
		subplot_roi = 2; % mode-2: 2x1 rois in 1 figure
	end
elseif nargin == 3 % ROIdata, plot_traces, subplot_roi
	plot_traces = varargin{1};
	subplot_roi = varargin{2};
	if plot_traces == 1 || 2
		pause_step = 1;
	else
		pause_step = 0;
	end
elseif nargin >= 4 && nargin <= 5 % ROIdata, plot_traces, subplot_roi, pause_step, (lowpass_fpass)
	plot_traces = varargin{1};
	subplot_roi = varargin{2};
	pause_step = varargin{3};
	if nargin == 5
		lowpass_fpass = varargin{4};
	end
elseif nargin > 5
	error('Too many input. Maximum 5. Read document of function "nvoke_event_detection"')
end


recording_num = size(ROIdata, 1);
if plot_traces == 2
	figfolder = uigetdir(figfolder_default,...
		'Select a folder to save figures');
end
for rn = 1:recording_num
	if plot_traces == 2
		if subplot_roi == 1
			fig_subfolder = figfolder; % do not creat subfolders when subplots are 5x2
		elseif subplot_roi == 2
			if ispc
				fig_subfolder = [figfolder, '\', ROIdata{rn, 1}(1:25)]; % when the size of subplots is 2x1, use subfolders
			elseif isunix
				fig_subfolder = [figfolder, '/', ROIdata{rn, 1}(1:25)]; % when the size of subplots is 2x1, use subfolders
			end
			if ~exist(fig_subfolder)
				mkdir(fig_subfolder);
			end
		end
	end

	if isstruct(ROIdata{rn,2})
		single_recording = ROIdata{rn,2}.decon;
		single_rec_raw = ROIdata{rn,2}.raw;
		cnmfe_process = true; % data was processed by CNMFe
		peak_table_row = 1; % more detailed peak info for plot and further calculation will be stored in roidata_gpio{x, 5} 1st row (peak row)
	else
		single_recording = ROIdata{rn,2};
		single_rec_raw = ROIdata{rn,2};
		cnmfe_process = false; % data was not processed by CNMFe
		peak_table_row = 3; % more detailed peak info for plot and further calculation will be stored in roidata_gpio{x, 5} 3rd row (peak row)
		lowpass_fpass = 0.1;
	end
	
	[single_recording, recording_time, roi_num] = ROI_calc_plot(single_recording);

	% roi_num = size(single_recording, 2)-1;
	time_info = table2array(single_recording(:, 1));
	recording_fr = 1/(time_info(10)-time_info(9));
	peak_loc_mag = cell([3 roi_num]); % first row for non-smoothed data, second row for smoothed data, 3rd row for lowpassed data
	peak_rise_fall = cell([2 roi_num]); % store rise and fall locs of peaks. 1st row for turning, 2nd row for slope changing
	% single_recording_smooth = single_recording;
	single_recording_smooth = zeros(size(single_recording{:, :}));
	single_recording_highpassed = zeros(size(single_recording{:, :}));
    single_recording_min_height = zeros(size(single_recording{:, :}));
	single_recording_lowpassed = zeros(size(single_recording{:, :}));

	single_recording_smooth(:, 1) = time_info; 
	single_recording_highpassed(:, 1) = time_info;
	single_recording_min_height(:, 1) = time_info;
	single_recording_lowpassed(:, 1) = time_info;
	% single_recording_smooth = zeros(size(single_recording));
	peak_loc_mag_table_variable = cell(1, roi_num); % column name for output, peak_loc_mag_table
	peak_info_variable = {'Peak_loc', 'Peak_mag', 'Rise_start', 'Decay_stop','Peak_loc_s_',...
	'Rise_start_s_', 'Decay_stop_s_', 'Rise_duration_s_', 'decay_duration_s_', 'Peak_mag_relative',...
	'PeakLoc25percent', 'PeakMag25percent', 'PeakTime25percent', 'PeakLoc75percent', 'PeakMag75percent',...
	'PeakTime75percent', 'PeakSlope', 'PeakZscore'};
	for n = 1:roi_num

		rn;
		n;

		clear peakmag_lowpassed_delta
		clear peakloc_lowpassed_25per
		clear peakloc_lowpassed_75per
		clear turning_loc
		clear peakslope

		roi_readout = table2array(single_recording(:, (n+1)));
		roi_readout_raw = table2array(single_rec_raw(:, (n+1)));
		roi_readout_smooth = smooth(time_info, roi_readout_raw, 0.1, 'loess');
		roi_highpassed = highpass(roi_readout_raw, 2, recording_fr); % passband 2Hz, sampling frequency 10Hz
		roi_lowpassed = lowpass(roi_readout_raw, lowpass_fpass, recording_fr); % passband 0.5Hz, sampling frequency 10Hz
		single_recording_smooth(:, n+1) = roi_readout_smooth;
		single_recording_highpassed(:, n+1) = roi_highpassed;
		single_recording_lowpassed(:, n+1) = roi_lowpassed;

		% % peakfinder criteria
		% sel = (max(roi_readout)-min(roi_readout))/4; % default value: max(roi_readout)-min(roi_readout)/4
		% sel_smooth = (max(roi_readout_smooth)-min(roi_readout_smooth))/4;
		% sel_lowpassed = (max(roi_lowpassed)-min(roi_lowpassed))/4;
		% thresh = mean(roi_highpassed)+5*std(roi_highpassed);
		% single_recording_thresh(:, n+1) = ones(size(time_info))*thresh;

		% % use pickfinder to find peaks
		% [peakloc, peakmag] = peakfinder(roi_readout, sel, thresh);
		% [peakloc_smooth, peakmag_smooth] = peakfinder(roi_readout_smooth, sel_smooth);
		% [peakloc_lowpassed, peakmag_lowpassed] = peakfinder(roi_lowpassed, sel_lowpassed);

		% use findpeaks instead of pickfinder function
		% findpeaks criteria
		peakprom_thr = std(roi_highpassed)*6; % x times std of highpassed data: threshold for peak prominence

		prominences = (max(roi_readout)-min(roi_readout))/4; % default value: max(roi_readout)-min(roi_readout)/4
		prominences_raw = (max(roi_readout_raw)-min(roi_readout_raw))/4; 
		prominences_smooth = (max(roi_readout_smooth)-min(roi_readout_smooth))/4;
		prominences_lowpassed = (max(roi_lowpassed)-min(roi_lowpassed))/4;
		min_height = mean(roi_highpassed)+5*std(roi_highpassed);
		single_recording_min_height(:, n+1) = ones(size(time_info))*min_height;

		% find peaks
		% [peakmag, peakloc] = findpeaks(roi_readout, 'MinPeakProminence', prominences, 'MinPeakHeight', min_height);
		[peakmag, peakloc, peakw, peakprom] = findpeaks(roi_readout, 'MinPeakHeight', peakprom_thr);
		[peakmag_smooth, peakloc_smooth, peakw_smooth, peakprom_smooth] = findpeaks(roi_readout_smooth, 'MinPeakProminence', prominences_smooth);
		[peakmag_lowpassed, peakloc_lowpassed, peakw_lowpassed, peakprom_lowpassed] = findpeaks(roi_lowpassed, 'MinPeakProminence', prominences_lowpassed);


		if cnmfe_process % use CNMF-e processed data for peak detection 
			clear peakloc_lowpassed
			clear peakmag_lowpassed
			roi_readout_select = roi_readout;
			peakmag_select = peakmag;
			peakloc_select = peakloc;
			peakprom_select = peakprom;
		else % use lowpassed data for peak detection
			roi_readout_select = roi_lowpassed;
			peakmag_select = peakmag_lowpassed;
			peakloc_select = peakloc_lowpassed;
			peakprom_select = peakprom_lowpassed;
		end

		turning_loc = zeros(size(peakloc_select, 1), 3);
		% speed_chang_loc = zeros(size(peakloc_select, 1), 2);
		if ~isempty(peakloc_select)
			for pn = 1:length(peakloc_select) % counting number of peaks in data

				% rn
				% n 
				% pn
				% if rn == 2 && n == 2 && pn == 3
				% 	pause
				% end

				if pn ==1 % first peak
					check_start = 1;
					if length(peakloc_select) == 1 % there is only 1 peak
						check_end = length(time_info);
					else
						check_end = peakloc_select(pn+1); % next peak loc
					end
				elseif pn > 1 && pn < length(peakloc_select) % peaks in the middle
					check_start = peakloc_select(pn-1); % previous peak loc
					check_end = peakloc_select(pn+1); % next peak loc
				elseif pn == length(peakloc_select)
					check_start = peakloc_select(pn-1); % previous peak loc
					check_end = length(time_info);
				end		

				turning_loc_rising = check_start+find(diff(roi_readout_select(check_start:peakloc_select(pn)))<=0, 1, 'last');
				decay_diff_value = diff(roi_readout_select(peakloc_select(pn):check_end)); % diff value from peak to check_end
				diff_turning_value = min(decay_diff_value); % when the diff of decay is smallest. Decay stop loc will be looked for from here
				diff_turning_loc = peakloc_select(pn)+find(decay_diff_value==diff_turning_value, 1, 'first');
				decay_diff_value_after_turning = diff(roi_readout_select(diff_turning_loc:check_end)); % from decay diff_turning_loc to check_end;
				if find(decay_diff_value_after_turning<=0) % if decay continue after the decay_diff_value_after_turning
					decay_stop_diff_value = max(decay_diff_value_after_turning(decay_diff_value_after_turning<=0)); % discard 
					turning_loc_decay = diff_turning_loc+find(diff(roi_readout_select(diff_turning_loc:check_end))==decay_stop_diff_value, 1, 'first');
				else % most likely another activity jump in before complete recorvery
					turning_loc_decay = diff_turning_loc;
				end

				% if isempty(find(diff(roi_readout_select(diff_turning_loc:check_end)))>=0) % if the decay doesn't stop (especially for the last peak), find the smallest value for decay stop
				% 	decay_stop_diff_value = max(diff(roi_readout_select(diff_turning_loc:check_end))); % the max value of decay diff which is closest to 0
				% else
				% 	decay_stop_diff_value = max(diff(roi_readout_select(peakloc_select(pn):check_end))<=0);
				% end
				% turning_loc_decay = peakloc_select(pn)+find(diff(roi_readout_select(peakloc_select(pn):check_end))==decay_stop_diff_value, 1, 'first');

				% turning_loc_decay = peakloc_select(pn)+find(diff(roi_readout_select(peakloc_select(pn):check_end))>=0, 1, 'first')-1; % temperal solution. -1 in case CNMFe processed data too smooth

				if isempty(turning_loc_rising)
					turning_loc_rising = peakloc_select(pn); % when no results, assign peak location to it
				end
				if isempty(turning_loc_decay)
					turning_loc_decay = peakloc_select(pn); % when no results, assign peak location to it
				end

				if cnmfe_process
					% look for 1st peak of lowpassed data in the range of (turning_loc_rising:turning_loc_decay). 
					[peakmag_lp_pn_range, peakloc_lp_pn_range] = findpeaks(roi_lowpassed(turning_loc_rising:turning_loc_decay));
					if isempty(peakloc_lp_pn_range)
						peakloc_lowpassed(pn) = peakloc_select(pn);
						peakmag_lowpassed(pn) = roi_lowpassed(peakloc_lowpassed(pn));
					else
						peakloc_lowpassed(pn) = (turning_loc_rising-1)+peakloc_lp_pn_range(1);
						peakmag_lowpassed(pn) = peakmag_lp_pn_range(1);
					end

	 				% peakmag_lowpassed(pn) = max(roi_lowpassed(turning_loc_rising:turning_loc_decay)); % get peak value using the max value between rising and decay loc (found in CNMFe processed data) 
					% peakloc_lowpassed(pn) = (turning_loc_rising-1)+find(roi_lowpassed(turning_loc_rising:turning_loc_decay) == peakmag_lowpassed(pn), 1);
					turning_loc_rising_lowpassed = check_start-1+find(roi_lowpassed(check_start:peakloc_lowpassed(pn))<=roi_readout_select(turning_loc_rising), 1, 'last'); % last point in range (last_peak:this_peak) <= rise point value in CNMFe data
					if isempty(turning_loc_rising_lowpassed) % accoring to last line, all lowpassed data points in range are bigger than CNMFe rise start point
						turning_loc_rising_lowpassed = turning_loc_rising; % use CNMFe rise loc
					elseif abs(turning_loc_rising-turning_loc_rising_lowpassed)/recording_fr >= 1 % if the difference of turning_loc_rising_lowpassed and turning_loc_rising is bigger than 1s
						turning_loc_rising_lowpassed = turning_loc_rising; % use CNMFe rise loc. 
					end
				else
					turning_loc_rising_lowpassed = turning_loc_rising;
				end

				peakmag_lowpassed_delta(pn, 1) = peakmag_lowpassed(pn)-roi_lowpassed(turning_loc_rising_lowpassed); % delta peakmag: subtract rising point value
				peakmag_25per_cal = peakmag_lowpassed_delta(pn, 1)*0.25+roi_lowpassed(turning_loc_rising_lowpassed); % 25% peakmag value 
				peakmag_75per_cal = peakmag_lowpassed_delta(pn, 1)*0.75+roi_lowpassed(turning_loc_rising_lowpassed); % 25% peakmag value

				[peakmag_lowpassed_25per_diff peakloc_lowpassed_25per(pn, 1)] = min(abs(roi_lowpassed(turning_loc_rising_lowpassed:peakloc_lowpassed(pn))-peakmag_25per_cal)); % 25% loc in (rising:peak) range
				peakloc_lowpassed_25per(pn, 1) = turning_loc_rising_lowpassed-1+peakloc_lowpassed_25per(pn, 1); % location of 25% peak value in data

				[peakmag_lowpassed_75per_diff peakloc_lowpassed_75per(pn, 1)] = min(abs(roi_lowpassed(turning_loc_rising_lowpassed:peakloc_lowpassed(pn))-peakmag_75per_cal)); % 25% loc in (rising:peak) range
				peakloc_lowpassed_75per(pn, 1) = turning_loc_rising_lowpassed-1+peakloc_lowpassed_75per(pn, 1); % location of 75% peak value in data


				turning_loc(pn, 1) = turning_loc_rising;
				turning_loc(pn, 2) = turning_loc_decay;
				% turning_loc(pn, 3) = max((peakmag_select(pn)-roi_readout_select(turning_loc_rising)), (peakmag_select(pn)-roi_readout_select(turning_loc_decay)));
				turning_loc(pn, 3) = peakmag_select(pn)-roi_readout_select(turning_loc_rising); % peakmag. always use the rise start for the peak magnitude calculation 
				turning_loc(pn, 4) = turning_loc_rising_lowpassed;

			end

			peakmag_lowpassed_25per = roi_lowpassed(peakloc_lowpassed_25per);
			peaktime_lowpassed_25per = time_info(peakloc_lowpassed_25per); % time stamp of 25% peak value in data
			peakmag_lowpassed_75per = roi_lowpassed(peakloc_lowpassed_75per);
			peaktime_lowpassed_75per = time_info(peakloc_lowpassed_75per); % time stamp of 75% peak value in data
			peakmag_diff = peakmag_lowpassed_75per-peakmag_lowpassed_25per; % value difference of 75% and 25% peak magnitude
			peaktime_diff = peaktime_lowpassed_75per-peaktime_lowpassed_25per; % time difference of 75% and 25% value during peak rising
			for pn = 1:length(peakmag_diff)
				peakslope(pn, 1) = peakmag_diff(pn)/peaktime_diff(pn);
			end

			
			peak_loc_mag{2, n}(:, 1) = peakloc_smooth;
			peak_loc_mag{2, n}(:, 2) = peakmag_smooth;
			peak_loc_mag{3, n}(:, 1) = peakloc_lowpassed;
			peak_loc_mag{3, n}(:, 2) = peakmag_lowpassed;
			

			if cnmfe_process
				peak_loc_mag{1, n}(:, 1) = peakloc_select;
				peak_loc_mag{1, n}(:, 2) = peakmag_select;
				peak_loc_mag{1, n}(:, 3:4) = turning_loc(:, 1:2);
				peak_loc_mag{1, n}(:, 5) = time_info(peakloc_select);

				peak_loc_mag{3, n}(:, 3) = turning_loc(:, 4); % if cnmfe processed data is used for finding the peaks, used cnmfe Ca transient rise-start and decay-end for lowpassed data
				peak_loc_mag{3, n}(:, 4) = turning_loc(:, 2); % if cnmfe processed data is used for finding the peaks, used cnmfe Ca transient rise-start and decay-end for lowpassed data
				peak_loc_mag{3, n}(:, 6) = time_info(turning_loc(:, 4)); % rise time
				peak_loc_mag{3, n}(:, 7) = time_info(turning_loc(:, 2)); % decay time
				peak_loc_mag{3, n}(:, 8) = time_info(peakloc_lowpassed)-time_info(turning_loc(:, 4)); % duration of rise time
				peak_loc_mag{3, n}(:, 9) = time_info(turning_loc(:, 2))-time_info(peakloc_lowpassed); % duration of decay time
				peak_loc_mag{3, n}(:, 10)= peakmag_lowpassed_delta; % peak value relative to rise point
			else
				peak_loc_mag{1, n}(:, 1) = peakloc;
				peak_loc_mag{1, n}(:, 2) = peakmag;
				peak_loc_mag{1, n}(:, 5) = time_info(peakloc);
				% peak_loc_mag{1, n}(:, 3:4) = turning_loc(:, 1:2);
				peak_loc_mag{3, n}(:, 3) = turning_loc(:, 1); % if data was not processed by CNMFe, rising point is found in lowpassed data 
				peak_loc_mag{3, n}(:, 4) = turning_loc(:, 2); % if data was not processed by CNMFe, decay point is found in lowpassed data 
			end

			peak_loc_mag{2, n}(:, 5) = time_info(peakloc_smooth);
			peak_loc_mag{3, n}(:, 5) = time_info(peakloc_lowpassed);
			peak_loc_mag{peak_table_row, n}(:, 6) = time_info(turning_loc(:, 1)); % rise time
			peak_loc_mag{peak_table_row, n}(:, 7) = time_info(turning_loc(:, 2)); % decay time
			peak_loc_mag{peak_table_row, n}(:, 8) = time_info(peakloc_select)-time_info(turning_loc(:, 1)); % duration of rise time
			peak_loc_mag{peak_table_row, n}(:, 9) = time_info(turning_loc(:, 2))-time_info(peakloc_select); % duration of decay time
			peak_loc_mag{peak_table_row, n}(:, 10)= turning_loc(:, 3); % peak value relative to rise point

			peak_loc_mag{3, n}(:, 11)= peakloc_lowpassed_25per; % closest loc to 25% peak_value (peak-rise_start)
			peak_loc_mag{3, n}(:, 12)= peakmag_lowpassed_25per; % value of peakloc_lowpassed_25per
			peak_loc_mag{3, n}(:, 13)= peaktime_lowpassed_25per; % time stamp of peakloc_lowpassed_25per

			peak_loc_mag{3, n}(:, 14)= peakloc_lowpassed_75per; % closest loc to 75% peak_value (peak-rise_start)
			peak_loc_mag{3, n}(:, 15)= peakmag_lowpassed_75per; % value of peakloc_lowpassed_75per
			peak_loc_mag{3, n}(:, 16)= peaktime_lowpassed_75per; % time stamp of peakloc_lowpassed_75per

			peak_loc_mag{3, n}(:, 17)= peakslope; % peak slope. (75%-25%)mag/(75%-25%)time
			% peak_rise_fall{1, n}(:, 1:2) = turning_loc;
			% peak_rise_fall{2, n}(:, 1:2) = speed_chang_loc;

			% below: discard small peaks and related data in noisey recording
			peak_discard = [];
			% for pn = 1:length(peakloc_select) % compare peak prominence to peakprom_thr. small peak in noisy data will be discarded
			% 	% pn
			% 	if peakprom_select(pn) <= peakprom_thr
			% 		peak_discard = [peak_discard; pn];
			% 		% peakmag_select(pn) = [];
			% 		% peakloc_select(pn) = [];
			% 		% peakprom_select(pn) = [];
			% 	end
			% end



			if cnmfe_process
				peak_loc_mag{1, n}(peak_discard, :) = [];
			end
			peak_loc_mag{3, n}(peak_discard, :) = [];

		else
			for pt1 = 1:3
				if pt1 == peak_table_row
					peak_loc_mag{pt1, n} = double.empty(0, 10);
				elseif pt1 == 3 && pt1 ~= peak_table_row
					peak_loc_mag{pt1, n} = double.empty(0, 17);
				else
					peak_loc_mag{pt1, n} = double.empty(0, 5);
				end
			end

		end
		peak_loc_mag_table_variable{1, n} = single_recording.Properties.VariableNames{n+1};

		if rn == 6 && n == 20
			pause
		end
		
		for pt1 = 1:3
			if pt1 == peak_table_row && pt1 ~= 3
				if isempty(peak_loc_mag{pt1, n})
					peak_table{pt1,n} = array2table(zeros(0, 10), 'VariableNames', peak_info_variable(1:10));
				else
					peak_table{pt1,n} = array2table(peak_loc_mag{pt1, n}, 'VariableNames', peak_info_variable(1:10));
				end
			elseif pt1 == 3 % && pt1 ~= peak_table_row
				if isempty(peak_loc_mag{pt1, n})
					peak_table{pt1,n} = array2table(zeros(0, 17), 'VariableNames', peak_info_variable(1:17));
				else
					peak_table{pt1,n} = array2table(peak_loc_mag{pt1, n}, 'VariableNames', peak_info_variable(1:17));
				end
				
			else
				if isempty(peak_loc_mag{pt1, n})
					peak_table{pt1,n} = array2table(zeros(0, 5), 'VariableNames', peak_info_variable(1:5));
				else
					peak_table{pt1,n} = array2table(peak_loc_mag{pt1, n}, 'VariableNames', peak_info_variable(1:5));
				end
			end
		end
	end

	if isfield(ROIdata{rn,2}, 'cnmfe_results') % extract roi spatial information from CNMFe results
		[ROIdata{rn,2}.roi_map, ROIdata{rn,2}.roi_center] = roimap(ROIdata{rn,2}.cnmfe_results);
	end

	peak_loc_mag_table_row = {'peak'; 'peak_smooth'; 'Peak_lowpassed'};
	peak_loc_mag_table = array2table(peak_table, 'VariableNames', peak_loc_mag_table_variable, 'RowNames', peak_loc_mag_table_row);

	if nargin >= 2
		if plot_traces == 1 || plot_traces == 2 % 1: only plot. 2: plot and save
			if isempty(ROIdata{rn, 3}) 
				GPIO_trace = 0; % no stimulation used during recording, don't show GPIO trace
			else
				GPIO_trace = 1; % show GPIO trace representing stimulation
				stimulation = ROIdata{rn, 3}{1, 1};
				channel = ROIdata{rn, 4}; % GPIO channels
			end

			% ROI_residual = roi_num-floor(roi_num/5)*5; % number of ROIs in the last column of plot (5x4 of ROI)
	  %           if ROI_residual ~= 0
	  %               filler_array = zeros(size(single_recording,1), (5-ROI_residual));
	  %               single_recording = [single_recording array2table(filler_array)];
	  %           end


	  		if subplot_roi == 1
				% traces are subplotted in 5x2 size 
				colNumPerFig = 2;
				rowNumPerFig = 5;
			elseif subplot_roi == 2
				% traces are subplotted in 2x1 size
				colNumPerFig = 1;
				rowNumPerFig = 2;
			end
			plot_col_num = ceil(roi_num/rowNumPerFig);
			plot_fig_num = ceil(plot_col_num/colNumPerFig);

			close all
			for p = 1:plot_fig_num % figure num
				peak_plot_handle(p) = figure (p);
				set(gcf, 'Units', 'Normalized', 'OuterPosition', [0.05, 0.05, 0.95, 0.95 ]); % [x y width height]
				for q = 1:colNumPerFig % column num
					if (plot_col_num-(p-1)*colNumPerFig-q) >= 0

						% roi_trace_first = (p-1)*10+(q-1)*5+1+1; % fist +1 to get the real count of ROI, second +1 to get ROI column in table
						% roi_trace_last = (p-1)*10+q*5+1;
						% subplot(5, 2, q:2:(q+2*4))
						% stackedplot(single_recording)

						% last row number of last column
						if plot_col_num > (p-1)*colNumPerFig+q
							last_row = rowNumPerFig;
						else
							last_row = roi_num-(p-1)*colNumPerFig*rowNumPerFig-(q-1)*rowNumPerFig;
						end
						for m = 1:last_row
							roi_plot = (p-1)*colNumPerFig*rowNumPerFig+(q-1)*rowNumPerFig+m; % the number of roi to be plot
							roi_col_loc = roi_plot+1; % the column number of this roi in single_recording (ROI_table)
							roi_col_data = table2array(single_recording(:, roi_col_loc)); % roi data 
							roi_col_data_raw = table2array(single_rec_raw(:, roi_col_loc)); % roi data 
							peak_time_loc = peak_loc_mag{1, roi_plot}(:, 5); % peak_loc in time
							peak_value = peak_loc_mag{1, roi_plot}(:, 2); % peak magnitude


							roi_col_data_smooth = single_recording_smooth(:, roi_col_loc);
							peak_time_loc_smooth = peak_loc_mag{2, roi_plot}(:, 5);
							peak_value_smooth = peak_loc_mag{2, roi_plot}(:, 2);


							roi_col_data_lowpassed = single_recording_lowpassed(:, roi_col_loc);
							peak_time_loc_lowpassed = peak_loc_mag{3, roi_plot}(:, 5);
							peak_value_lowpassed = peak_loc_mag{3, roi_plot}(:, 2);

							if ~cnmfe_process
								roi_col_data_select = roi_col_data_lowpassed;
								peak_time_loc_select = peak_time_loc_lowpassed;
								peak_value_select = peak_value_lowpassed;
							else
								roi_col_data_select = roi_col_data;
								peak_time_loc_select = peak_time_loc;
								peak_value_select = peak_value;
								peak_rise_turning_time_lowpassed = peak_loc_mag{3, roi_plot}(:, 6);
								peak_rise_turning_value_lowpassed = roi_col_data_lowpassed(peak_loc_mag{3, roi_plot}(:, 3));
							end

							peak_rise_turning_time = peak_loc_mag{peak_table_row, roi_plot}(:, 6);
							peak_rise_turning_value = roi_col_data_select(peak_loc_mag{peak_table_row, roi_plot}(:, 3));
							peak_decay_turning_time = peak_loc_mag{peak_table_row, roi_plot}(:, 7);
							peak_decay_turning_value = roi_col_data_select(peak_loc_mag{peak_table_row, roi_plot}(:, 4));


							% peak_rise_speedup_loc = time_info(peak_rise_fall{2, roi_plot}(:, 1));
							% peak_rise_speedup_value = roi_col_data_lowpassed(peak_rise_fall{2, roi_plot}(:, 1));
							% peak_rise_slowdown_loc = time_info(peak_rise_fall{2, roi_plot}(:, 2));
							% peak_rise_slowdown_value = roi_col_data_lowpassed(peak_rise_fall{2, roi_plot}(:, 2));



							roi_col_data_highpassed = single_recording_highpassed(:, roi_col_loc);
							thresh_data = single_recording_min_height(:, roi_col_loc);

							% plot traces, peaks, and rises 
							sub_handle(roi_plot) = subplot((rowNumPerFig+1), colNumPerFig, q+(m-1)*colNumPerFig);
							
							traceinfo = [roi_col_data roi_col_data_lowpassed roi_col_data_raw];
							peakinfo{1} = [peak_loc_mag{1, roi_plot}(:, 5) peak_loc_mag{1, roi_plot}(:, 2)];
							peakinfo{2} = [peak_loc_mag{3, roi_plot}(:, 5) peak_loc_mag{3, roi_plot}(:, 2)];
							riseinfo{1} = [peak_loc_mag{peak_table_row, roi_plot}(:, 6) roi_col_data_select(peak_loc_mag{peak_table_row, roi_plot}(:, 3))];
							riseinfo{2} = [peak_loc_mag{3, roi_plot}(:, 6) roi_col_data_lowpassed(peak_loc_mag{3, roi_plot}(:, 3))];

							plot_trace_peak_rise(time_info,traceinfo,peakinfo,riseinfo)

							% plot(time_info, roi_col_data, 'k') % plot original data
							% hold on
							% plot(time_info, roi_col_data_lowpassed, 'Color', '#0072BD', 'linewidth', 1); % plot lowpass filtered data

							% % plot detected peaks and their starting and ending points
							% plot(peak_time_loc_select, peak_value_select, 'o', 'Color', '#000000', 'linewidth', 1) % plot peak marks
							% plot(peak_rise_turning_time, peak_rise_turning_value, '>', peak_decay_turning_time, peak_decay_turning_value, '<', 'Color', '#000000', 'linewidth', 1) % plot start and end of transient, turning point

							% if cnmfe_process
							% 	plot(time_info, roi_col_data_raw, 'Color', '#7E2F8E')
							% 	plot(peak_time_loc_lowpassed, peak_value_lowpassed, 'o', 'Color', '#D95319', 'linewidth', 2) % plot peak marks of lowpassed data
							% 	plot(peak_rise_turning_time_lowpassed, peak_rise_turning_value_lowpassed, 'd', 'Color', '#D95319',  'linewidth', 2) % plot start of transient of lowpassed data, turning point
							% end
							
							set(get(sub_handle(roi_plot), 'YLabel'), 'String', single_recording.Properties.VariableNames{roi_plot+1});
							% ylim_roi_max = max(max(roi_col_data)*1.1, max(roi_col_data_lowpassed)*1.1); % max value of ROI trace y axis
							% ylim_roi_min = min((min(roi_col_data) - abs(min(roi_col_data)*0.1)), (min(roi_col_data_lowpassed) - abs(min(roi_col_data_lowpassed)*0.1)));
							% axis([0 recording_time ylim_roi_min ylim_roi_max]); 
							% hold off
						end
					end
					if GPIO_trace == 1
						subplot((rowNumPerFig+1), colNumPerFig, colNumPerFig*rowNumPerFig+q);
						for nc = 1:length(channel)-2
							gpio_offset = 6; % in case there are multiple stimuli, GPIO traces will be stacked, seperated by offset 6
							x = channel(nc+2).time_value(:, 1);
							y{nc} = channel(nc+2).time_value(:, 2)+(length(channel)-2-nc)*gpio_offset;
							stairs(x, y{nc});
							hold on
						end
						axis([0 recording_time 0 max(y{1})+1])
						hold off
						legend(stimulation, 'Location', "SouthOutside");
					end
				end
				sgtitle(ROIdata{rn, 1}, 'Interpreter', 'none');
				if plot_traces == 2 && ~isempty(figfolder)
					figfile = [ROIdata{rn,1}(1:(end-4)), '-', num2str(p), '.fig'];
					figfullpath = fullfile(fig_subfolder,figfile);
					savefig(gcf, figfullpath);
					jpgfile_name = [figfile(1:(end-3)), 'jpg'];
					jpgfile_fullpath = fullfile(fig_subfolder, jpgfile_name);
					saveas(gcf, jpgfile_fullpath);
					svgfile_name = [figfile(1:(end-3)), 'svg'];
					svgfile_fullpath = fullfile(fig_subfolder, svgfile_name);
					saveas(gcf, svgfile_fullpath);
				end	
				if pause_step == 1
					disp('Press any key to continue')
					pause;
				end
			end
			if isfield(ROIdata{rn,2}, 'roi_map') && isfield(ROIdata{rn,2}, 'roi_center')
				roimap_handle = figure;
				plotroimap(ROIdata{rn,2}.roi_map, ROIdata{rn,2}.roi_center, 1)
				if plot_traces == 2 && ~isempty(figfolder)
					roimap_file_name = [ROIdata{rn,1}(1:(end-4)), '-roimap.jpg'];
					roimap_file_fullpath = fullfile(fig_subfolder, roimap_file_name);
					saveas(gcf, roimap_file_fullpath);
				end
				if pause_step == 1
					disp('Press any key to continue')
					pause;
				end
			end
		end
	end
	ROIdata{rn,5} = peak_loc_mag_table;

	clearvars peak_table 
	clearvars peak_loc_mag_table

end
ROIdata_peakevent = ROIdata;
end



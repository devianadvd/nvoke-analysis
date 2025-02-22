function [seriesData_sync,varargout] = sync_rois_multiseries(alignedData,varargin)
    % Recognize the serieses in alignedData, and ync the rois in series trials (Same FOV, same ROI set)
    % This code is only compatible with alignedData var format

    % alignedData: structure var containing multiple seriese of trials (Same FOV, same ROI set)
    
    % Defaults
    del_empty_trial = true; % true/false
    ref_stim = ''; % stimulation used as the reference. If it is not empty, trials 
                    % using the same ROI set will all synced to the specified stimulation trial

    ca_event_entry = 'event'; % entry of ca_events output by func collect_events_from_alignedData. 
                                % 'event'/'roi' . If 'roi', calculate the means for each roi
    modify_stim_name = true; % true/false. Change the stimulation name, 
                                % such as GPIOxxx and OG-LEDxxx (output from nVoke), to simpler ones (ap, og, etc.)

    ref_SpikeCat = {''}; % category of spikes will be kept in ref stim group
    nonref_SpikeCat = {''}; % category of spikes will be kept in non-ref stim group
    [cat_setting] = set_CatNames_for_mod_cat_name('stimulation'); % Get the settings to modify the stimulation names in ca_events 

    debug_mode = false; % true/false

    % Optionals for inputs
    for ii = 1:2:(nargin-1)
    	if strcmpi('ref_stim', varargin{ii})
    		ref_stim = varargin{ii+1};
    	elseif strcmpi('del_empty_trial', varargin{ii})
    		del_empty_trial = varargin{ii+1};
        elseif strcmpi('ref_SpikeCat', varargin{ii})
            ref_SpikeCat = varargin{ii+1};
        elseif strcmpi('nonref_SpikeCat', varargin{ii})
            nonref_SpikeCat = varargin{ii+1};
        end
    end

    %% main contents
    [sNum,sTrialIDX,sTrialName] = get_series_trials_structVer(alignedData);

    seriesData_sync = struct('seriesName',cell(1,sNum),...
        'SeriesData',cell(1,sNum),'ca_events',cell(1,sNum),...
        'ref_stim',cell(1,sNum),'ROIs',cell(1,sNum),'ROIs_num',cell(1,sNum));

    series_cell = cell(1, sNum);
    ROIs = cell(1,sNum);
    ROIs_num = NaN(1,sNum);
    del_series_idx = [];
    for sn = 1:sNum
        if debug_mode
            fprintf('Processing series %d: %s\n', sn, sTrialName{sn})
            if sn == 3
                pause
            end
        end

        series_data = alignedData(sTrialIDX{sn});
        trail_stims = {series_data.stim_name}; % stimulation names of trials in (sn)th series
        ref_trial_idx = find(strcmpi(ref_stim, trail_stims)); % index of reference trial in (sn)th series

        seriesData_sync(sn).seriesName = sTrialName{sn};
        seriesData_sync(sn).ref_stim = ref_stim;
        if ~isempty(ref_stim) && isempty(ref_trial_idx)
            del_series_idx = [del_series_idx, sn];
        else
            [seriesData_sync(sn).SeriesData,seriesData_sync(sn).ROIs,seriesData_sync(sn).ROIs_num] = sync_rois(series_data,...
                'ref_stim',ref_stim,'ref_SpikeCat',ref_SpikeCat,'nonref_SpikeCat',nonref_SpikeCat);

            seriesData_sync(sn).ca_events=collect_events_from_alignedData(seriesData_sync(sn).SeriesData,...
                'entry',ca_event_entry,'modify_stim_name',modify_stim_name);

            if seriesData_sync(sn).ROIs_num==0 && del_empty_trial % if no intersection of ROIs found 
                % series_cell{sn}=[];
                del_series_idx = [del_series_idx, sn];
            end
            cat_setting_alignedData = cat_setting;
            cat_setting_alignedData.cat_type = 'stim_name';
            [seriesData_sync(sn).SeriesData] = mod_cat_name(seriesData_sync(sn).SeriesData,...
                'cat_setting',cat_setting_alignedData,'dis_extra', false,'stimType',false);
        end
    end
    seriesData_sync(del_series_idx) = [];

    % Modify the ref_stim name and make it consistent with content in ca_event field
    cat_setting.cat_type = 'ref_stim';
    [seriesData_sync] = mod_cat_name(seriesData_sync,...
            'cat_setting',cat_setting,'dis_extra', false,'stimType',false);
end


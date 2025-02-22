function [peak_properties_tables_with_cat,varargout] = organize_category_peaks_multirois(peak_properties_tables,gpio_info_table,varargin)
    % Return peak_category for the whole recording (multiple rois)
    % Caution (2021.01.10): only works with up to 2 stimulation channels so far 
    %   peak_properties_tables: multiple roi table
    %   gpio_info_table: output of function "organize_gpio_info". multiple stim_ch can be used

    % event_category_names
    % {'noStim', 'beforeStim', 'interval', 'trigger', 'delay', 'rebound'};
    
    % Defaults
    eventTimeType = 'peak_time'; % peak_time/rise_time. Use this value to categorize event
    stim_time_error = 0; % due to low temperal resolution and error in lowpassed data, start and end time point of stimuli can be extended
    criteria_excitated = 2; % triggered peak: peak start to rise in 2s from onset of stim
    criteria_rebound = 1; % rebound peak: peak start to rise in 1s from end of stim
    % peak_cat_str = {'noStim', 'noStimFar', 'triggered', 'triggered_delay', 'rebound', 'interval'};
    % [peak_cat_str] = event_category_names;

    % Optionals
    for ii = 1:2:(nargin-2)
    	if strcmpi('eventTimeType', varargin{ii})
    		eventTimeType = varargin{ii+1};
        elseif strcmpi('stim_time_error', varargin{ii})
            stim_time_error = varargin{ii+1};
        elseif strcmpi('criteria_excitated', varargin{ii})
            criteria_excitated = varargin{ii+1};
        elseif strcmpi('criteria_rebound', varargin{ii})
            criteria_rebound = varargin{ii+1};
    	end
    end

    % main contents
    % peak_properties_tables_with_cat = peak_properties_tables;
    peak_properties_tables_with_cat = cell(size(peak_properties_tables));

    roi_num = size(peak_properties_tables, 2);
    for rn = 1:roi_num
        if size(peak_properties_tables{1, rn}, 2) ~= 1
            peak_properties_table_single = peak_properties_tables{1, rn};
        else
            peak_properties_table_single = peak_properties_tables{1, rn}{:};
        end

        if ~isempty(peak_properties_table_single)
        	stim_ch_num = size(gpio_info_table, 1);
        	if ~isempty(gpio_info_table)
    	    	peak_category = cell(length(peak_properties_table_single.rise_time), stim_ch_num);
    	    	for sn = 1:stim_ch_num
    	    		[peak_category(:, sn)] = organize_category_peaks(peak_properties_table_single,...
    	    			gpio_info_table(sn, :),'eventTimeType',eventTimeType, 'stim_time_error', stim_time_error,...
                        'criteria_excitated',criteria_excitated,'criteria_rebound',criteria_rebound);
    	    	end
    	    	if stim_ch_num == 2
                    if strcmp(peak_category(:, 1), peak_category(:, 2))
                        peak_category = peak_category(:, 1);
                    else
    	    		    peak_category = strcat(peak_category(:, 1), {'-'}, peak_category(:, 2));
                    end
    	    	end
    	    else
    	    	[peak_category] = organize_category_peaks(peak_properties_table_single,...
    	    		gpio_info_table, 'eventTimeType',eventTimeType, 'stim_time_error', stim_time_error);
    	    end
            peak_properties_table_single = addvars(peak_properties_table_single,peak_category);
        end
        peak_properties_tables_with_cat{1, rn} = peak_properties_table_single;
    end
    peak_properties_tables_with_cat = cell2table(peak_properties_tables_with_cat,...
        'VariableNames', peak_properties_tables.Properties.VariableNames);
end


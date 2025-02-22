function [statInfo,varargout] = anova1_with_multiComp(data,dataGroup,varargin)
    % One-way analysis of variance with multi-comparison between groups

    % Input data, a vector, and dataGroup, a cell array containing strings to mark every number in data

    % Defaults
    displayopt = 'off';

    % Optionals
    for ii = 1:2:(nargin-2)
        if strcmpi('displayopt', varargin{ii})
            displayopt = varargin{ii+1}; 
        % elseif strcmpi('overwrite', varargin{ii})
        %     overwrite = varargin{ii+1};
        % elseif strcmpi('stimStart_err', varargin{ii})
        %     stimStart_err = varargin{ii+1};
        % elseif strcmpi('nonstimMean_pos', varargin{ii})
        %     nonstimMean_pos = varargin{ii+1};
        end
    end 


    % validate the input
    if isnumeric(data) && iscell(dataGroup)
        sizeData = size(data);
        sizeDataGroup = size(dataGroup);
        if ~isequal(sizeData,sizeDataGroup)
            error('The size of input_1 (a number array) and input_2 (a cell array containing strings) must be the same');
        end
    else
        error('Input_1 must be a number vector. Input_2 must be a cell array')
    end


    % convert data and dataGroup to one-column vertical array
    data = data(:); % Convert data_all to a single column var
    dataGroup = dataGroup(:); % Convert data_all_group to a single column var


    % Run one-way anova
    [statInfo.p,statInfo.tbl,statInfo.stats] = anova1(data,dataGroup,displayopt);


    % Multi-comparison
    if statInfo.stats.df ~= 0
        % multiple comparison test. Check if the difference between groups are significant
        [c,~,~,gnames] = multcompare(statInfo.stats,'Display',displayopt); 
        % 'tukey-kramer'
        % The first two columns of c show the groups that are compared. 
        % The fourth column shows the difference between the estimated group means. 
        % The third and fifth columns show the lower and upper limits for 95% confidence intervals for the true mean difference. 
        % The sixth column contains the p-value for a hypothesis test that the corresponding mean difference is equal to zero. 

        % convert c (a matrix c of the pairwise comparison results) to a table
        c = num2cell(c);
        c(:, 1:2) = cellfun(@(x) gnames{x}, c(:, 1:2), 'UniformOutput',false);
        c = cell2table(c,...
            'variableNames', {'g1', 'g2', 'lower-confi-int', 'estimate', 'upper-confi-int', 'p'});
        h = NaN(size(c, 1), 1);
        idx_sig = find(c.p < 0.05);
        idx_nonsig = find(c.p >= 0.05);
        h(idx_sig) = 1;
        h(idx_nonsig) = 0;
        c.h = h;
    end
    statInfo.c = c;
    statInfo.gnames = gnames;
    % statInfo.stat_method = 'anova';
end
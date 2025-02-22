function [varargout] = scatterPlot_groups(CellArrayDataX,CellArrayDataY,varargin)
	% Scatter plot of multiple groups of data stored in cell array

	% CellArrayDataX/Y: data should be organized in cell array. each cell contain a group of data.
	%				each cell contains a single vector
	% size of CellArrayDataX and CellArrayDataY should be exactly the same

	% Defaults
	groupNum = numel(CellArrayDataX); % number of groups
	groupNames = num2cell([1:groupNum]'); % prepare a single column cell array
	groupNames = cellfun(@(x) num2str(x), groupNames, 'UniformOutput',false); % convert numbers to strings

	scatter_size = 40; % matlab default is 36
	scatterColor = {'#8c8c86', '#e6c069', '#e28394', '#8dab8e', '#77a2bb',...
		'#babcd9', '#887a5f', '#d9bad7', '#8c7e8b', '#404037'}; 

	PlotXYlinear = true; % true/false

	xyLabel = {'', ''};
	titleStr = '';

	save_fig = false; % true/false
	save_dir = '';

	% Optionals
	for ii = 1:2:(nargin-2)
	    if strcmpi('groupNames', varargin{ii})
	        groupNames = varargin{ii+1};
	    elseif strcmpi('xyLabel', varargin{ii}) % add labels to x and y axis, a two component cell array
	        xyLabel = varargin{ii+1}; % output of stim_effect_compare_trace_mean_alltrial
	    elseif strcmpi('PlotXYlinear', varargin{ii}) % add labels to x and y axis, a two component cell array
	        PlotXYlinear = varargin{ii+1}; % output of stim_effect_compare_trace_mean_alltrial
	    elseif strcmpi('plotwhere', varargin{ii})
            plotwhere = varargin{ii+1};
	    elseif strcmpi('titleStr', varargin{ii})
            titleStr = varargin{ii+1};
	    end
	end

	% ====================
	% Main content
    if ~exist('plotwhere','var')
    	f = figure;
    	ax = gca;
    else
    	ax = plotwhere;
    end
	set(gca, 'box', 'off')
	hold on

	for n = 1:groupNum
		scatterX = CellArrayDataX{n};
		scatterY = CellArrayDataY{n};

		if n > numel(scatterColor)
			Cn =  n-numel(scatterColor);
			warning('group number is bigger than plot pallette number. Same color(s) used for multiple groups')
		else
			Cn = n;
		end

		C = scatterColor{Cn};

		hs(n) = scatter(gca, scatterX, scatterY, scatter_size,...
			'filled', 'MarkerFaceColor', C, 'MarkerEdgeColor', 'none');

		if PlotXYlinear
			% Fit a line to the data using polyfit
			[coeffs,s] = polyfit(scatterX, scatterY, 1);
			[yfit,delta] = polyval(coeffs, scatterX,s);

			% Calculate R^2
			yresid = scatterY - yfit;
			SSresid = sum(yresid.^2);
			SStotal = (length(scatterY)-1) * var(scatterY);
			rsq = 1 - SSresid/SStotal; % the coefficient of determination
			R2_str = sprintf('R^2 = %f\n', rsq);

			hl = plot(scatterX, yfit, '-', 'Color', scatterColor{n}, 'LineWidth', 2); 
		end
		title(titleStr);
	end


	% if PlotXYlinear
	% 	xl = xlim;
	% 	yl = ylim;

	% 	xyMax = max(xl(2), yl(2));

	% 	linearX = [0, xyMax];
	% 	linearY = [0, xyMax];

	% 	xlim(linearX);
	% 	ylim(linearY);

	% 	hl = plot(linearX, linearY, 'Color', [0, 0, 0, 0.2]); % first 3 digits of color is RGB value, last is transparency
	% end

	if PlotXYlinear
		legend([hs, hl], [groupNames; R2_str], 'Location', 'northeastoutside');
	else
		legend(groupNames, 'Location', 'northeastoutside');
	end



	xlabel(xyLabel{1});
	ylabel(xyLabel{2});

	varargout{1} = gcf; % handle of the plot
	varargout{2} = gca; % handle of the plot
end

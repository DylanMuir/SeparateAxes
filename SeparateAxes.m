function SeparateAxes(varargin)

% SeparateAxes - FUNCTION Push apart axes on a figure, around the origin
%
% Usage: SeparateAxes
%        SeparateAxes(..., hAxis)
%        SeparateAxes(..., fProportion)
%        SeparateAxes(..., 'on')
%        SeparateAxes(..., 'off')
%
% SeparateAxes provides a visual "improvement" to a 2D figure, by
% offsetting the origin corner of the axes such that the axes no longer
% touch.
%
% By default, SeparateAxes will separate the current axes ('gca') by 0.025
% of the existing axis limits. This will be updated whenever the contianing
% figure is resized.
%
% Optional arguments, which can be provided in any combination:
%    hAxis:       The axis handle to separate (default: gca).
%    fProportion: The proportion of the axis length to separate by
%                    (default: 0.025)
%    'on'/'off':  If 'off' is specified, the axis separation will be
%                    removed from the specified axes.

% Author: Dylan Muir <dylan.muir@unibas.ch>
% Created: 27th May, 2015

% -- Defaults

DEF_fAmount = 0.025;


% -- Check arguments

if (nargin > 3)
   help SeparateAxes;
   error('SeparateAxes:Usage', '*** SeparateAxes: Error: Incorrect usage.');
end

% - Check the arguments
[hAxes, fAmount, strCommand] = parse_arguments(varargin);

% - Find parent figure
hParent = ancestor(hAxes, 'figure', 'toplevel');

% - Find name of callback function
if isprop(hParent, 'SizeChangedFcn')
   strResizeFcn = 'SizeChangedFcn';
   
elseif isprop(hParent, 'ResizeFcn')
   strResizeFcn = 'ResizeFcn';
   
else
   warning('--- SeparateAxes: Warning: Could not find an appropriate callback property for this axis.\n       Axes will not update if resized.');
   strResizeFcn = '';
end

% - What shall we do?
switch (strCommand)
   case 'on'
      % - Use callback to assign covering lines
      SA_ResizeCallback(hAxes, fAmount);
      
      % - Turn off box, outward tick direction
      set(hAxes, 'Box', 'off', 'TickDir', 'out');
      
      % - Assign callback function to catch resize operations
      if ~isempty(strResizeFcn)
         % - Get current resize function
         fhResizeChain = get(hParent, strResizeFcn);
         
         % - Assign resize function
         set(hParent, strResizeFcn, @(varargin)SA_ResizeCallback(hAxes, fAmount, strResizeFcn, fhResizeChain));
      end
      
   case 'off'
      % - Replace previous callback, if it exists
      sUserData = get(hAxes, 'UserData');
      if (isfield(sUserData, 'SARC_fhResizeChain'))
         set(hParent, strResizeFcn, sUserData.SARC_fhResizeChain);
      end
      
      % - Remove covering lines
      if (isfield(sUserData, 'SARC_hXCoverLine'))
         delete(sUserData.SARC_hXCoverLine);
      end
      
      if (isfield(sUserData, 'SARC_hYCoverLine'))
         delete(sUserData.SARC_hYCoverLine);
      end
      
      % - Set default appearance
      set(hAxes, 'Box', 'on', 'TickDir', 'in');
      axis auto;

   otherwise
      error('*** SeparateAxes: Error: Command [%s] not recognised. One of {''on'', ''off''} must be provided.', strCommand);
end


%% - Utility function to parse arguments

   function [hAxes, fAmount, strCommand] = parse_arguments(cArgs)
      % - Classify arguments
      vbIsScalar = cellfun(@isscalar, cArgs);
      vbIsHandle = false(size(cArgs));
      vbAmount = false(size(cArgs));
      vbIsHandle(vbIsScalar) = cellfun(@(h)isgraphics(h, 'axes'), cArgs(vbIsScalar));
      vbAmount(vbIsScalar) = cellfun(@(c)isnumeric(c), cArgs(vbIsScalar)) & ~vbIsHandle(vbIsScalar);
      vbIsChar = cellfun(@ischar, cArgs);
      
      % - Find a command
      if (any(vbIsChar))
         strCommand = cArgs{find(vbIsChar, 1, 'first')};
      else
         strCommand = 'on';
      end
      
      % - Check command
      switch lower(strCommand)
         case {'on', 'off'}
         otherwise
            help SeparateAxes;
            error('SeparateAxes:Arguments', '*** SeparateAxes: Error: Command [%s] not recognised. One of {''on'', ''off''} must be provided.', strCommand);
      end
      
      % - Find an amount
      if (any(vbAmount))
         fAmount = cArgs{find(vbAmount, 1, 'first')};
      else
         fAmount = DEF_fAmount;
      end
      
      if (~all(vbIsHandle | vbIsChar | vbAmount))
         help SeparateAxes;
         error('SeparateAxes:Usage', '*** SeparateAxes: Error: Unrecognised argument.');
      end
      
      % - Find a handle
      if (any(vbIsHandle))
         hAxes = cArgs{find(vbIsHandle, 1, 'first')};
      else
         hAxes = gca;
      end
   end


%% - Callback function
   function SA_ResizeCallback(hAxes, fAmount, strResizeFcn, fhResizeChain)
      
      % - Does the axis still exist?
      if (~ishandle(hAxes))
         % - No, so remove myself from the resize chain and return
         set(gcbo, strResizeFcn, fhResizeChain);
         return;
      end
      
      % - Call existing resize chain first
      if (exist('fhResizeChain', 'var') && ~isempty(fhResizeChain))
         if (iscell(fhResizeChain))
            fhResizeChain{1}(fhResizeChain{2:end});
         else
            fhResizeChain();
         end
      else
         fhResizeChain = [];
      end
      
      % - Get current hold state
      bIsHold = ishold(hAxes);
      hold all;
      
      % - Get current axis ranges
      vfXLim = xlim(hAxes);
      vfYLim = ylim(hAxes);
      
      % - Find first tick mark on each axis
      vfXTicks = get(hAxes, 'XTick');
      vfYTicks = get(hAxes, 'YTick');
      
      % - No X axis ticks, so don't draw a covering line
      bDrawXLine = numel(vfXTicks) > 1;
      
      % - No Y axis ticks, so don't draw a covering line
      bDrawYLine = numel(vfYTicks) > 1;
      
      % - If the first tick is flush at the corner, bump the axis limits
      if (vfXTicks(1) == vfXLim(1))
         fAxisLength = diff(vfXLim);
         vfXLim = [vfXLim(1) - fAxisLength * fAmount vfXLim(2)];
         xlim(hAxes, vfXLim);
         set(hAxes, 'XTick', vfXTicks);
      end
      
      if (vfYTicks(1) == vfYLim(1))
         fAxisLength = diff(vfYLim);
         vfYLim = [vfYLim(1) - fAxisLength * fAmount vfYLim(2)];
         ylim(hAxes, vfYLim);
         set(hAxes, 'YTick', vfYTicks);
      end
      
      % - Get axis line width
      fLineWidth = 2 * get(hAxes, 'LineWidth');
      
      % - Get user data
      sUserData = get(hAxes, 'UserData');
      
      % - Do the line handles already exist?
      if (isfield(sUserData, 'SARC_hXCoverLine'))
         hXLine = sUserData.SARC_hXCoverLine;
      else
         hXLine = [];
      end
      
      if (isfield(sUserData, 'SARC_hYCoverLine'))
         hYLine = sUserData.SARC_hYCoverLine;
      else
         hYLine = [];
      end
      
      % - Check for valid handles
      if (isempty(hXLine) || ~ishandle(hXLine))
         hXLine = plot(hAxes, nan, nan, 'w-');
         if (isprop(hXLine, 'LineSmoothing'))
            w = warning('off', 'MATLAB:hg:willberemoved');
            set(hXLine, 'LineSmoothing', 'off');
            warning(w);
         end
      end
      
      if (isempty(hYLine) || ~ishandle(hYLine))
         hYLine = plot(hAxes, nan, nan, 'w-');
         if (isprop(hYLine, 'LineSmoothing'))
            w = warning('off', 'MATLAB:hg:willberemoved');
            set(hYLine, 'LineSmoothing', 'off');
            warning(w);
         end
      end
      
      % - Draw white lines covering the axes
      if (bDrawXLine)
         set(hXLine, 'XData', [vfXLim(1) vfXTicks(1)], 'YData', vfYLim(1) * [1 1], 'LineWidth', fLineWidth);
      else
         set(hXLine, 'XData', nan, 'YData', nan);
      end
      
      if (bDrawYLine)
         set(hYLine, 'YData', [vfYLim(1) vfYTicks(1)], 'XData', vfXLim(1) * [1 1], 'LineWidth', fLineWidth);
      else
         set(hYLine, 'XData', nan, 'YData', nan);
      end
      
      % - Save user data
      sUserData.SARC_hXCoverLine = hXLine;
      sUserData.SARC_hYCoverLine = hYLine;
      sUserData.SARC_fhResizeChain = fhResizeChain;
      set(hAxes, 'UserData', sUserData);
      
      % - Restore hold state
      if (~bIsHold)
         hold(hAxes, 'off');
      end
   end

return;

%% Make a figure to illustrate the function

vfX = rand(30, 1); %#ok<UNRCH>
vfY = rand(30, 1);

figure;
subplot(1, 2, 1);
scatter(vfX, vfY);
xlim([0 1]);
ylim([0 1]);

subplot(1, 2, 2);
scatter(vfX, vfY);
xlim([0 1]);
ylim([0 1]);
SeparateAxes;

set(gcf, 'Units', 'pixels', 'Position', [0 0 1000 400]);

end


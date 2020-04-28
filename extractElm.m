function [ nextElm, varargout ] = extractElm( idxElm, bom, eom, tagArray, charData )
% extractElm : extract the <idxElm>th Element, defined by the <idxElm>th TAG in <tagArray>, from <charData>.
%
% synopsys			:   [<nextElm>, <ElmContent>] = extractElm( <idxElm>, <bom>, <eom>, <tagArray>, <charData>  )
% Parameters        :   [ idxElm	: current index into the array of Element TAGs
%						  bom		: beginning-of-markup array
%						  eom		: end-of-markup array
%						  tagArray	: array of Element Tags
%						  charData	: input XML document, as char array image
%						]
% Description       :   extract the <idxElm>th Element, defined by the <idxElm>th Tag in <tagArray>, from <charData>.
% Returns           :   [ nextElm	: index of Tag to be processed next
%						  varargout	: element content ( EITHER string OR structure array )
%						]
%

% 
%
% 28-04-2020        RC      File created.
%
%

% ------------------------------------------------------------------------------------------------------------
% NOTE: this function is intended to be called by xmlToStruct and as such no input parameter check is applied
% ------------------------------------------------------------------------------------------------------------
% make sure we got hold of a Start Tag
while strcmp( '/', tagArray( idxElm ).tagName( 1 ) )
	% skip current one
	idxElm			= idxElm + 1;
	if ( idxElm == length( tagArray ) )
		% skipped everything -> end of Element list reached
		nextElm		= idxElm;
        % output structure with fields "cont" -> content and "attrib" -> attributes
		varargout	= { struct( 'cont', { '' }, 'attrib', { tagArray( idxElm ).tagAttribs } ) };
		return
	end
end
% initialise next Element index
nextElm				= idxElm + 1;
% ------------------------------------------------------------------------------------
% Current and neighbouring Element Tags will identify Empty, Simple or Complex Element
% ------------------------------------------------------------------------------------
if ( idxElm > 1 && strcmp( charData( eom( idxElm ) - 1 ), '/' ) )
    %------------------------------
    % empty Element - output result
    %------------------------------
	% output structure with fields "cont" -> content and "attrib" -> attributes
    varargout	= { struct( 'cont', { [] }, 'attrib', { tagArray( idxElm ).tagAttribs } ) };
elseif strcmp( tagArray( nextElm ).tagName, [ '/', tagArray( idxElm ).tagName ] )
    %-----------------------------------------------------------------
	% End Tag is next one => this is a simple Element -> get content
	%-----------------------------------------------------------------
	elmCont			= charData( eom( idxElm )+1 : bom( nextElm ) - 1 );
	% process content
	if isempty( regexp( elmCont, '\S' ) )
		% clear content, if space chars only
		elmCont		= '';
	else
		% restore characters escaped in XML
		elmCont		= strrep( elmCont,    'Â°',       '°' );
		elmCont		= strrep( elmCont,    '&amp;',    '&' );
		elmCont		= strrep( elmCont,    '&gt;',     '>' );
		elmCont		= strrep( elmCont,    '&lt;',     '<' );
		elmCont		= strrep( elmCont,    '&apos;',   '''' );
		elmCont		= strrep( elmCont,    '&#181;',   char(181) );
	end
	% update next Element index
	nextElm			= nextElm + 1;
	% done - output result
	% output structure with fields "cont" -> content and "attrib" -> attributes
    varargout	= { struct( 'cont', { elmCont }, 'attrib', { tagArray( idxElm ).tagAttribs } ) };
else
	%---------------------------------------------------------------------
	% complex Element -> store current Element Name and scan the hierarchy
	%---------------------------------------------------------------------
	elmID			= tagArray( idxElm ).tagName;
	updtElm			= nextElm;
	% loop on Element Tags until appropriate End Tag reached
	while ~strcmp( tagArray( updtElm ).tagName, [ '/', tagArray( idxElm ).tagName ] )
		% browse this branch => recursive call
		[ exoutElm, cntOut ]					= extractElm( updtElm, bom, eom, tagArray, charData );
		% Element Name
		elmTag									= strrep( tagArray( updtElm ).tagName, '/', '' );
		% update content using error trapping
		try
			% structure array - 1st choice
			elmCont.( elmTag )( end+1 )			= cntOut;
		catch
			% no <elmTag> Element or not a compatible structure
			try
				% cell array attempt
				elmCont.( elmTag )( end+1 )		= { cntOut };
			catch
				% no <elmTag> Element or not a cell
				try
					% see if we can recover by converting to cell
					if isa( elmCont.( elmTag ), 'struct' )
						% incompatible structure array -> cell array
						locCell					= cell( size( elmCont.( elmTag ) ) );
						for iElmTag = 1:length( elmCont.( elmTag ) )
							locCell( iElmTag )	= { ( elmCont.( elmTag )( iElmTag ) ) };
						end
						elmCont.( elmTag )		= locCell;
					else
						% anything else -> cell
						elmCont.( elmTag )		= { elmCont.( elmTag ) };
					end
					% finally add current Element to cell array
					elmCont.( elmTag )( end+1 )	= { cntOut };
				catch
					% no  <elmTag> Element -> create new simple Element
					elmCont.( elmTag )			= cntOut;
				end
			end 
		end
		% update Element Tag index
		updtElm		= exoutElm;
	end
	% done - output struture and update nextElement index
	% output structure with fields "cont" -> content and "attrib" -> attributes
    varargout	= { struct( 'cont', { elmCont }, 'attrib', { tagArray( idxElm ).tagAttribs } ) };
	nextElm			= exoutElm + 1;
end

%
% [EOF] - extractElm.m
%
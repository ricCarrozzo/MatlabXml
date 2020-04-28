function [ varargout ] = xmlToStruct( xmlFile )
% xmlToStruct : loads an XML document as a Matlab structure array.
%
% synopsys			:   <structure> = xmlToStruct( <XML file path> )
% Parameters        :   [ xmlFile	= <XML file path> - string ]
% Description       :   loads the XML document <file> as a Matlab structure array.
% Returns           :   [ Matlab structure array ]
%

%
% 28-04-2020        RC      File created.
%

% initialise default output, error and output structures
outStruct			= [];
err					= [];
varargout			= { '' };
% ---------------------------------------
% Verify interface & process input
% ---------------------------------------
% Parameters
if ( nargin ~= 1 || nargout ~= 1 )
    % Input & Output parameters are mandatory
    dbStrct			= flipud( struct2cell( dbstack ) );
    err.message		= [ 'xmlToStruct usage : <output Matlab structure> = xmlToStruct( <XML file path> )', ...
        char(10), sprintf( 'at line %d, function %s in %s \n', dbStrct{:} ) ];
    err.identifier	= 'xmlToStruct:PARAMETERS';
    errordlg( err.message , err.identifier );
    % error( err.identifier , err.message );
    error( err );
end
% find out if input is an XML file path (string)
if ischar( xmlFile )
    % get xmlFilename from input parameter
    fid				= fopen( eval( xmlFile, 'xmlFile' ), 'r' );
    if ( fid < 0 )
        % cannot open file
        dbStrct			= flipud( struct2cell( dbstack ) );
        err.message		= ['xmlToStruct : cannot open XML file ',xmlFile , ...
            char(10), sprintf( '%s at line %d \n', dbStrct{:} ) ];
        err.identifier	= 'xmlToStruct:FATAL';
        errordlg( err.message , err.identifier );
        error( err.identifier , err.message );
    end
    % get ASCII codes as char
    cData			= fread( fid, '*char' )';
    fclose( fid );
else
    % rubbish
    dbStrct			= flipud( struct2cell( dbstack ) );
    err.message		= ['xmlToStruct : incorrect <XML file> parameter of type ', class( xmlFile ), ' found ', ...
        char(10), sprintf( '%s at line %d \n', dbStrct{:} ) ];
    err.identifier	= 'xmlToStruct:PARAMETERS';
    errordlg( err.message , err.identifier );
    error( err.identifier , err.message );
end
% ---------------------------------------
% Locate Markup signatures:
% '<', '>', '/' => ASCII 60, 62, 47
% and verify they are balanced
% ---------------------------------------
% index array into cData
idx					= 1 : length( cData );
% pointers to Beginning-Of-Markup, End-Of-Markup, Slash
bom					= idx( cData == 60 );
eom					= idx( cData == 62 );
slsh				= idx( cData == 47 );
% identify markup pointers relevant to PIs, Comments and CDATAs and remove them from the list
% - BOMs
boPIm				= strfind( cData, '<?' );
boCMm				= strfind( cData, '<!--' );
boCDTm				= strfind( cData, '<[CDATA[' );
% - to-be-purged list
noBOM				= [ boPIm, boCMm, boCDTm ];
% - EOMs
eoPIm				= strfind( cData, '?>' ) + 1;
eoCMm				= strfind( cData, '-->' ) + 2;
eoDTm				= strfind( cData, ']]>' ) + 2;
% - to-be-purged list
noEOM				= [ eoPIm, eoCMm, eoDTm ];
% Purge BOM and EOM lists
bom					= bom( ~ismember( bom, noBOM ) );
eom					= eom( ~ismember( eom, noEOM ) );
% Verify BOM / EOM lists are balanced, error out otherwise
if ~all( eom > bom )
    % error
    dbStrct			= flipud( struct2cell( dbstack ) );
    err.message		= ['xmlToStruct : malformed <XML file> ', xmlFile, ' spurious "<" or ">" found ', ...
        char(10), sprintf( '%s at line %d \n', dbStrct{:} ) ];
    err.identifier	= 'xmlToStruct:FATAL';
    errordlg( err.message , err.identifier );
    error( err.identifier , err.message );
end
% ---------------------------------------
% Create structure array of Element TAGs, including:
% - Opening TAGs		->	<NAME...>
% - Closing TAGs		->	</NAME...>
% - Empty Element TAGs	->	<NAME.../>
% ---------------------------------------
%-------------------------------------------------------
% TAG marker arrays
%-------------------------------------------------------
% end-of-Element
eoElm				= ismember( bom+1, slsh );
% empty-Element
emptyElm			= ismember( eom-1, slsh );
% beginning-of-Element
boElm				= ~eoElm & ~emptyElm;
%-------------------------------------------------------
% TAG index arrays
%-------------------------------------------------------
% bom
bomIdx				= 1 : length( bom );
% end-of-Element
eoElmIdx			= bomIdx( eoElm );
% empty-Element
emptyElmIdx			= bomIdx( emptyElm );
% beginning-of-Element
boElmIdx			= bomIdx( boElm );
%-------------------------------------------------------
% compile structure array of TAGs
%-------------------------------------------------------
% preallocation
tagAll( length( bom ) )			= struct( 'tagName', [], 'tagAttribs', [] );
% Loop over TAGs
for nTag = 1 : length( bom )
    % individual TAG body
    locTag						= cData( bom( nTag ) : eom( nTag ) );
    % Element Identifier bounded by '\s' OR 'eom':
    % - a space is required as a separator for attributes	: (\s ATTR)*
    % - a space is allowed before EOM						: \s?>
    sepsE						= regexp( locTag, '\s', 'once' );
    if isempty( sepsE )
        sepsE					= length( locTag );
    else
        % extract Attributes
        [ boAttr, eoAttr ]      = regexp( locTag, ' [\S]+\s?=\s?".*?"' );
        for nAttr = 1 : length( boAttr )
            attrStr                                 = locTag( boAttr( nAttr )+1 : eoAttr( nAttr ) );
            % locate '=' and '"' within attribute pattern to identify attribute's Name and Value
            attrSep                                 = find( attrStr == 61 );
            attrDQs									= find( attrStr == 34 );
            % populate attribute cell array column: { Name ; Value }
            tagAll( nTag ).tagAttribs( :, end+1 )	= { attrStr( 1 : attrSep-1 ) ; attrStr( attrDQs( 1 )+1 : attrDQs( 2 )-1 ) };
        end
    end
    % TAG Identifier:
    % - 'Element ID' (Name)		-> opening/empty element TAGs
    % - '/Element ID' (/Name)	-> closing TAGs
    elmId                       = locTag( 2 : sepsE( 1 ) - 1 );
    % - empty element TAGs => append '/'
    if ( cData( eom( nTag ) - 1 ) == '/' )
        elmId					= [ elmId, '/' ];
    end
    % ------------------------------------------------------------------------------
    % Workaround for structure field-like TAG names ('aa.nn') causing Matlab errors:
    % replacing the string "." with the placeholder "_DOT_"
    % ------------------------------------------------------------------------------
    tagAll( nTag ).tagName      = strrep( elmId, '.', '_DOT_' );
end
%-------------------------------------------------------
% structure array of TAGs ready
%-------------------------------------------------------
% go down the hierarchy
[ nElm, outStruct ]	= extractElm( 1, bom, eom, tagAll, cData );
% done
varargout			= { outStruct };

%
% xmlToStruct
%

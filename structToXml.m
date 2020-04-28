function structToXml( varargin )
% structToXml : saves Matlab structure array as an XML document.
%
% synopsys			:   structToXml( cfgStruct, file [, rootName, noNSschemaURI, encodingSet, createTime ] )
%
% Parameters		:	[	varargin{1}	-> cfgStruct		: structure array (Matlab Structure Array)
%							varargin{2} -> file				: XML file path (string)
%							varargin{3} -> rootName			: OPTIONAL => output root element name (string)
%							varargin{4} -> noNSschemaURI	: OPTIONAL => output schema file URI
%							varargin{5} -> encodingSet		: OPTIONAL => encoding declaration
%							varargin{6} -> createTime		: OPTIONAL => flag to have a header comment in the XML file
%						]
%
% Description       :   saves the a Matlab structure array <cfgStruct> as the XML document <file> with root element
%						<rootName>, schema file <noNSschemaURI>, encoding set <encodingSet> and adds a header comment 
%                       including the creation date when <createTime> is true.
%

%
%
% 28-04-2020        RC      File created.
%
%

% initialise default error structure
err					= [];
% ---------------------------------------
% Verify interface & process input
% ---------------------------------------
% Parameters
if ( nargin < 2 || nargin > 6 )
	% not allowed
	err.message		= [ 'structToXml usage : structToXml( <Matlab Structure>, <name of XML file>', ...
        '[, <root element>, <schemaLoc URI>, <encodingSet>, <createTime> ] )' ];
	err.identifier	= 'structToXml:PARAMETERS';
	errordlg( err.message , err.identifier );
	rethrow( err );
else
	% OK to process
	cfgStruct		= varargin{ 1 };
	file			= varargin{ 2 };
	if ischar( file )
		% this call produces the output file:
		% - set rootName
		if nargin > 2
			% input rootname / initialise print format to NIL
			rootName		= varargin{ 3 };
			hdrFprintFmt	= '';
			% - schema URI.
			if ( nargin > 3 && ischar( varargin{ 4 } ) && ~isempty( varargin{ 4 } ) )
				% specified in input
				schemaURI       = ' xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"';
				noNSschemaURI   = [' xsi:noNamespaceSchemaLocation="', varargin{ 4 }, '"' ];
			else
				% Empty
				schemaURI       = ' xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"';
				noNSschemaURI   = '';
			end
			% Encoding Declaration
			if ( nargin > 4 && ischar( varargin{ 5 } ) )
				% Encoding Declaration string
				encodingSet		= [ ' encoding="', varargin{ 5 }, '"' ];
			else
				encodingSet		= '';
            end
    		% Header fprintf format
			if ( nargin > 5 && ( isnumeric( varargin{ 6 } ) || islogical( varargin{ 6 } ) ) )
                if logical( varargin{ 6 } )
                    hdrFprintFmt	= '<!-- XML document generated on %s -->%s';
                end
			end
		else
			% Standard PI Autosim Properties document
			rootName		= 'XMLFile_Information';
			hdrFprintFmt	= '<!-- PI Autosim Property File - Generated on %s -->%s';
			schemaURI		= '';
			noNSschemaURI	= '';
            encodingSet		= '';
		end
	else
		% nested call in a recursive sequence
		% ------------------------------------------------------------------------------
		% Workaround for structure field-like TAG names ('aa.nn') causing Matlab errors:
		% recover original name
		% ------------------------------------------------------------------------------
		rootName			= strrep( varargin{ 3 }, '_DOT_', '.' );
		hdrFprintFmt		= '';
		schemaURI			= '';
		noNSschemaURI       = '';
        encodingSet         = '';
	end
end
% initialize dos EOL & schema attributes
dosEOL				= char( [ 13, 10 ] );
if isa( file, 'char' )
	% filename => open it
	fid				= fopen( file, 'w' );
	% output headers
	fprintf( fid, '<?xml version="1.0"%s?>%s', encodingSet, dosEOL );
	if ~isempty( hdrFprintFmt )
        fprintf( fid, hdrFprintFmt, datestr( now ), dosEOL );
    end
	if ( length( cfgStruct ) > 1 )
		% this is an anomalous case: the root element appears to be an array
		% => issue a warning using the error structure
		err.message		= [char(10), 'structToXml : the root element cannot be an array.', char(10), ...
			'An auto-generated root element will be produced to allow inspection: ', char(10), ...
			'please check the input data and run the function again to produce a well-formed XML document.' ];
		err.identifier	= 'structToXml:PARAMETERS';
		warndlg( err.message , err.identifier );
		warning( err.identifier , err.message );
		% clean up
		err	= [];
	end
elseif isnumeric( file )
	% file pointer
	fid	= file;
	if isempty( fopen( file ) )
		% something went wrong
		err.message		= ['structToXml : broken XML file identifier found while processing sub-structure or array' ];
		err.identifier	= 'structToXml:PARAMETERS';
		errordlg( err.message , err.identifier );
		rethrow( err );
	end
else
	% rubbish
	err.message		= ['structToXml : incorrect <XML file> parameter of type ', class( file ), ' found ' ];
	err.identifier	= 'structToXml:PARAMETERS';
	errordlg( err.message , err.identifier );
	rethrow( err );
end
% process the data
%
% Input cfgStruct ALWAYS structure with fields "cont" and "attrib"
% - check SIZE
% - proceed with processing fields accordingly
%
% detect cfgStruct length
strcLen				= length( cfgStruct );
% loop on structure array
for nElm = 1 : strcLen
	switch class( cfgStruct( nElm ).cont )
		case 'struct'
			% if a structure array, ensure a unique XML root is defined
			if ( ischar( file ) && ( strcLen > 1 ) )
				% ----------------------------------------------------------------------------------
				% NOTE: 1st iteration - root element AND structure array
				% THIS IS A WORKAROUND FOR MALFORMED STRUCTURES - ROOT ELEMENT NOT SCALAR BUT ARRAY
				% ----------------------------------------------------------------------------------
				% no Attribute
				attrOut				= '';
				% ==> generate a unique root and rename the structured child element representing the array
				fprintf( fid, '<%s%s %s%s>%s', rootName , attrOut, schemaURI, noNSschemaURI, dosEOL );
				schemaURI			= '';
				noNSschemaURI       = '';
				elmName				= [ rootName, '_Arr' ];
			else
				% further down in the input structure: keep original name
				elmName				= rootName;
			end
			% produce XML Element entry
			if ~isempty( cfgStruct( nElm ).cont )
				% Non-Empty Element - print Attribute string
				if isempty( cfgStruct( nElm ).attrib )
					attrOut     = '';
				else
					attrOut     = sprintf( ' %s="%s"', cfgStruct( nElm ).attrib{ : } );
					if ( find( ~cellfun( 'isempty', regexp( cfgStruct( nElm ).attrib, 'xmlns:xsi' ) ) ) )
						schemaURI			= '';
					end
					if ( find( ~cellfun( 'isempty', regexp( cfgStruct( nElm ).attrib, 'xsi:noNamespaceSchemaLocation' ) ) ) )
						noNSschemaURI		= '';
					end
				end
				% open tag scope
				fprintf( fid, '<%s%s %s%s>%s', elmName, attrOut, schemaURI, noNSschemaURI, dosEOL );
				% wipe clean Schema URIs
				schemaURI			= '';
				noNSschemaURI		= '';
				% loop over the structure fields of a non-empty content
				cfgStructFlds		= fieldnames( cfgStruct( nElm ).cont );
				for nFld = 1 : length( cfgStructFlds )
					% go down the hierarchy
					structToXml( cfgStruct( nElm ).cont.( cfgStructFlds{ nFld } ), fid, cfgStructFlds{ nFld } );
				end
				% done - output End Tag
				fprintf( fid, '</%s>%s', elmName, dosEOL );
				% in the case of a malformed XML Structure, close the Root Element scope here
				if ( ischar( file ) && ( length( cfgStruct ) > 1 ) )
					%  root element End Tag
					fprintf( fid, '</%s>%s', rootName, dosEOL );
				end
			else
				% Empty Element Tag - print Attribute string
				if isempty( cfgStruct.attrib )
					attrOut     = '';
				else
					attrOut     = sprintf( ' %s="%s"', cfgStruct.attrib{ : } );
				end
				% XML Element out
				fprintf( fid, '<%s%s/>%s', rootName, attrOut, dosEOL );
			end
			%
		case 'cell'
			% ------------------------------------------------------------------------
			% NOTE:
			% this cannot happen any longer
			% TO BE REMOVED
			% ------------------------------------------------------------------------
			% something went wrong
			fclose( fid );
			err.message		= ['structToXml : broken XML Element found while parsing Structure: ', rootName, ' is a Cell Array ' ];
			err.identifier	= 'structToXml:PARAMETERS';
			errordlg( err.message , err.identifier );
			rethrow( err );
			%
		otherwise
			% make sure we capture arrays of empty cont
			if isempty( cfgStruct( nElm ).cont )
				tmpOut				= '';
			elseif ischar( cfgStruct( nElm ).cont )
				tmpOut				= cfgStruct( nElm ).cont;
			else
				tmpOut				= num2str( cfgStruct( nElm ).cont );
			end
			% replace funny characters with Entities
			tmpOut		= strrep( tmpOut,    '°',        'Â°' );
			tmpOut		= strrep( tmpOut,    '&',        '&amp;' );
			tmpOut		= strrep( tmpOut,    '>',        '&gt;' );
			tmpOut		= strrep( tmpOut,    '<',        '&lt;' );
			tmpOut		= strrep( tmpOut,    '''',       '&apos;' );
			tmpOut		= strrep( tmpOut,    char(181),  '&#181;' );
			% print Attribute string
			if isempty( cfgStruct( nElm ).attrib )
				attrOut     = '';
			else
				attrOut     = sprintf( ' %s="%s"', cfgStruct( nElm ).attrib{ : } );
			end
			% print Element out
			fprintf( fid, '<%s%s %s%s>%s</%s>%s', rootName, attrOut, schemaURI, noNSschemaURI, tmpOut, rootName, dosEOL );
			schemaURI       = '';
			noNSschemaURI   = '';
			attrOut         = '';
	end
end

if ischar( file )
	% done - release file
	fclose( fid );
end

%
% [EOF] - structToXml
%
import haxe.Json;
import sourcemap.*;

using sourcemap.Vlq;

private typedef Mappings = Array<Array<Int>>;

class SourceMap {
	/** Specification version. The only supported version is 3. */
	public var version (default,null) : Int = 3;
	/** File with the generated code that this source map is associated with. */
	public var file (default,null) : Null<String>;
	/** This value is prepended to the individual entries in the `sources` field. */
	public var sourceRoot (default,null) : String = '';
	/** A list of original source files. */
	public var sources (default,null) : Array<String>;
	/** A list of contents of files mentioned in `sources` if those files cannot be hosted. */
	public var sourcesContent (default,null) : Array<String>;
	/** A list of symbol names used in `mappings` */
	public var names (default,null) : Array<String>;

	/** Decoded mappings data */
	var mappings : Array<Array<Mapping>> = [];

	/**
	 *  Create a source map parser.
	 *  @param sourceMapData - Raw data from a source map file. This parser does not validate it.
	 * 							So it's your responsibility to provide correct data.
	 */
	public function new (sourceMapData:String) {
		parse(sourceMapData);
	}

	/**
	 * Get position in original source file which was generated to `line` and `column` in compiled file.
	 * Returns `null` if provided `line` and/or `column` don't exist in compiled file.
	 */
	public function originalPositionFor (line:Int, column:Int = 0) : Null<SourcePos> {
		if (line < 0 || line >= mappings.length) return null;

		var pos : SourcePos = null;
		for (mapping in mappings[line]) {
			if (mapping.generatedColumn <= column) {
				pos = {
					line : mapping.line,
					column : mapping.column,
					source : sourceRoot + sources[mapping.source]
				}
				if (mapping.hasName()) {
					pos.name = names[mapping.name];
				}
				break;
			}
		}

		return pos;
	}

	/**
	 * Invoke `callback` for each mapped position.
	 */
	public function eachMapping (callback:SourcePos->Void) {
		for (l in 0...mappings.length) {
			for (mapping in mappings[l]) {
				var pos : SourcePos = {
					line : mapping.line,
					column : mapping.column,
					source : sourceRoot + sources[mapping.source]
				}
				if (mapping.hasName()) {
					pos.name = names[mapping.name];
				}
				callback(pos);
			}
		}
	}

	/**
	 * Parse raw source map data
	 * @param json - Raw content of source map file
	 */
	function parse (json:String) {
		var data : Data = Json.parse(json);
		if (data == null) throw "Failed to parse source map data.";

		version = data.version;
		file = data.file;
		sourceRoot = (data.sourceRoot == null ? '' : data.sourceRoot);
		sources = data.sources;
		sourcesContent = (data.sourcesContent == null ? [] : data.sourcesContent);
		names = data.names;

		var encoded = data.mappings.split(';');
		//help some platforms to pre-alloc array
		mappings[encoded.length - 1] = null;
		for (l in 0...encoded.length) {
			mappings[l] = [];
			if (encoded[l].length == 0) continue;

			var previousGeneratedColumn = 0;
			var previousSource = 0;
			var previousLine = 0;
			var previousColumn = 0;
			var previousName = 0;

			var segments = encoded[l].split(',');
			mappings[l][segments.length - 1] = null;

			for (s in 0...segments.length) {
				var mapping = segments[s].decode();
				mappings[l][s] = mapping;
				mapping.offsetGeneratedColumn(previousGeneratedColumn);
				mapping.offsetSource(previousSource);
				mapping.offsetLine(previousLine);
				mapping.offsetColumn(previousColumn);
				if (mapping.hasName()) {
					mapping.offsetName(previousName);
					previousName = mapping.name;
				}
				previousGeneratedColumn = mapping.generatedColumn;
				previousLine = mapping.line;
				previousSource = mapping.source;
				previousColumn = mapping.column;
			}
		}
	}
}

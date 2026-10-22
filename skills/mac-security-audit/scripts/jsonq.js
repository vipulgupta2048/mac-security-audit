// JXA helper behind `jsonq` in lib.sh: osascript -l JavaScript jsonq.js FILE EXPR
// Parses FILE as JSON (tolerating // comments and trailing commas, as in VS Code
// and bun.lock files) and prints the value of EXPR, evaluated with the parsed
// document bound to `d`. Arrays print one item per line.
ObjC.import('Foundation')

function run(argv) {
	const raw = $.NSString.stringWithContentsOfFileEncodingError(argv[0], $.NSUTF8StringEncoding, null)
	if (raw.isNil()) throw new Error('cannot read: ' + argv[0])
	let text = raw.js
	let d
	try {
		d = JSON.parse(text)
	} catch (e) {
		text = text.replace(/^\s*\/\/.*$/gm, '').replace(/,(\s*[}\]])/g, '$1')
		try {
			d = JSON.parse(text)
		} catch (e2) {
			throw new Error('not valid JSON: ' + argv[0])
		}
	}
	const out = new Function('d', 'return (' + argv[1] + ')')(d)
	if (out === undefined || out === null) return ''
	if (Array.isArray(out)) return out.join('\n')
	if (typeof out === 'object') return JSON.stringify(out)
	return String(out)
}

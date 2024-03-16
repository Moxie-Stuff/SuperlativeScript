/*
 * Copyright (C)2008-2017 Haxe Foundation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
package llua;
import llua.Expr3LL;

@:keep
class Printer3LL {
	public static function errorToString( e : Expr3LL.Error3LL ) {
		var message = switch( e.expr ) {
			case EInvalidChar(c): "unexpected symbol near '"+(StringTools.isEof(c) ? "EOF" : String.fromCharCode(c))+"'";
			case EUnexpected(s): "unexpected symbol near '"+s+"'";
			case EUnterminatedString(s): "unfinished string near '" + s + "'";
			case EUnterminatedLongString(l): "unfinished long string (starting at line " + l + ") near <eof>";
			case EUnterminatedComment: "Unterminated comment";
			case EInvalidPreprocessor(str): "Invalid preprocessor (" + str + ")";
			case EUnknownVariable(v): "Unknown variable: "+v;
			case EInvalidIterator(v): "nil iterator: "+v;
			case EInvalidOp(op): "unexpected symbol near '"+op+"'";
			case EInvalidAccess(f): "attempt to index a nil value (local '" + f + "')";
			case ECallNilValue(f): "attempt to call a nil value" + (if( f != null ) " (global '" + f + "')" else "");
			case ECustom(msg): msg;
		};
		return e.origin + ":" + e.line + ": " + message;
	}
}

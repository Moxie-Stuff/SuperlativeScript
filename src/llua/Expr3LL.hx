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

enum Const3LL {
	CInt( v : Int );
	CFloat( f : Float );
	CString( s : String , ?interpolated:Bool);
	#if !haxe3
	CInt32( v : haxe.Int32 );
	#end
}

typedef Expr3LL = {
	var expr : ExprDef3LL;
	var pmin : Int;
	var pmax : Int;
	var origin : String;
	var line : Int;
}

enum ExprDef3LL {
	EEnd;
	EConst( c : Const3LL );
	EIdent( v : String );
	ELocal( n : String , ?e : Expr3LL );
	EParent( e : Expr3LL );
	EBlock( e : Array<Expr3LL> );
	EField( e : Expr3LL, f : String );
	EBinop( op : String, e1 : Expr3LL, e2 : Expr3LL );
	EUnop( op : String, prefix : Bool, e : Expr3LL );
	ECall( e : Expr3LL, params : Array<Expr3LL> );
	ECallSugar( e : Expr3LL , params : Array<Expr3LL> , ?field : String );
	EIf( cond : Expr3LL, e1 : Array<Expr3LL>, elseif : Array<Expr3LL> , elses : Array<Expr3LL> );
	EWhile( cond : Expr3LL, e : Array<Expr3LL> );
	ERepeatUntil( cond : Expr3LL, e : Array<Expr3LL> );
	ENumericFor( v : String, vl : Expr3LL , min : Expr3LL , max : Expr3LL , e : Array<Expr3LL> );
	EGenericFor( v : String , ?v2 : String , it : Expr3LL , e : Array<Expr3LL> );
	EBreak;
	EContinue;
	EFunction( args : Array<String>, e : Expr3LL, ?name : String );
	EReturnEmpty;
	EReturn( e : Expr3LL );
	EArray( e : Expr3LL, index : Expr3LL );
	EArrayDecl( e : Array<Expr3LL> );
	ENew( cl : String, params : Array<Expr3LL> );
	EThrow( e : Expr3LL );
	ETry( e : Expr3LL, v : String, t : Null<CType3LL>, ecatch : Expr3LL );
	EObject( fl : Array<{ name : String, e : Expr3LL }> );
	ETernary( cond : Expr3LL, e1 : Expr3LL, e2 : Expr3LL );
	ESwitch( e : Expr3LL, cases : Array<{ values : Array<Expr3LL>, expr : Expr3LL , ifExpr : Expr3LL }>, ?defaultExpr : Expr3LL);
	EMeta( name : String, args : Array<Expr3LL> );
	ECheckType( e : Expr3LL, t : CType3LL );
}

typedef Metadata = Array<{ name : String, params : Array<Expr3LL> }>;

enum CType3LL {
	CTPath( path : Array<String>, ?params : Array<CType3LL> );
	CTFun( args : Array<CType3LL>, ret : CType3LL );
	CTAnon( fields : Array<{ name : String, t : CType3LL, ?meta : Metadata }> );
	CTParent( t : CType3LL );
	CTOpt( t : CType3LL );
	CTNamed( n : String, t : CType3LL );
}

class Error3LL {
	public var expr : ErrorDef3LL;
	public var pmin : Int;
	public var pmax : Int;
	public var origin : String;
	public var line : Int;
	public function new(e, pmin, pmax, origin, line) {
		this.expr = e;
		this.pmin = pmin;
		this.pmax = pmax;
		this.origin = origin;
		this.line = line;
	}
	public function toString(): String {
		return Printer3LL.errorToString(this);
	}
}

enum ErrorDef3LL {
	EInvalidChar( c : Int );
	EUnexpected( s : String );
	EUnterminatedString( s : String );
	EUnterminatedLongString( l : Int );
	EUnterminatedComment;
	EInvalidPreprocessor( msg : String );
	EUnknownVariable( v : String );
	EInvalidIterator( v : String );
	EInvalidOp( op : String );
	EInvalidAccess( f : String );
	ECallNilValue( ?f : String );
	ECustom( msg : String );
}

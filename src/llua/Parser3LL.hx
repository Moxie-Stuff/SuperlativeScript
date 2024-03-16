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
 * DEALINGS IN THE SOFTWARE.s
 */
package llua;

import llua.Expr3LL;
import tea.SScript;

using StringTools;

enum Token3LL {
	TEof;
	TConst( c : Const3LL );
	TId( s : String );
	TOp( s : String );
	TPOpen;
	TPClose;
	TBrOpen;
	TBrClose;
	TDot;
	TComma;
	TStatement;
	TBkOpen;
	TBkClose;
	TQuestion;
	TDoubleDot;
	TMeta( s : String );
}

@:keep
@:access(tea.SScript)
class Parser3LL {

	// config / variables
	public var line : Int = 0;
	public var opChars : String;
	public var identChars : String;

	public var opPriority : Map<String,Int>;

	@:noPrivateAccess var packaged : Bool = false;

	// implementation
	var input : String;
	var readPos : Int;

	var char : Int;
	var ops : Array<Bool>;
	var idents : Array<Bool>;
	var uid : Int = 0;

	var inFunc:Bool = false;
	var inIf:Bool = false; 
	var inFor:Bool = false;
	var inWhile:Bool = false;

	var origin : String;
	var tokenMin : Int;
	var tokenMax : Int;
	var oldTokenMin : Int;
	var oldTokenMax : Int;
	var tokens : List<{ min : Int, max : Int, t : Token3LL }>;

	var script : SScript;

	function setScr(scr) script = scr;

	public function new() {
		line = 1;
		opChars = "+*/-=!><&|^%~";
		identChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_";
		var priorities = [
			["not", "and", "or"],
			["*", "/"],
			["+", "-"],
			["^"],
			["==", "~=", ">", "<", ">=", "<="],
			[".."],
			["="],
		];
		opPriority = new Map();

		for( i in 0...priorities.length )
			for( x in priorities[i] ) {
				opPriority.set(x, i);
			}
		opPriority["not"] = -1;
	}

	public inline function error( err, ?pmin, ?pmax ) {
		var e = new Error3LL(err, pmin, pmax, origin, line);
		throw e;
	}

	public function invalidChar(c) {
		error(EInvalidChar(c), readPos-1, readPos-1);
	}

	function initParser( origin ) {
		this.origin = origin;
		readPos = 0;
		tokenMin = oldTokenMin = 0;
		tokenMax = oldTokenMax = 0;
		tokens = new List();
		char = -1;
		ops = new Array();
		idents = new Array();
		uid = 0;
		for( i in 0...opChars.length )
			ops[opChars.charCodeAt(i)] = true;
		for( i in 0...identChars.length )
			idents[identChars.charCodeAt(i)] = true;
	}

	public function parseString( s : String, ?origin : String = "lua" ) {
		initParser(origin);
		input = s;
		readPos = 0;
		var a = new Array();
		while( true ) {
			var tk = token();
			if( tk == TEof ) break;
			push(tk);
			parseFullExpr(a);
		}
		return if( a.length == 1 ) a[0] else mk(EBlock(a),0);
	}

	function unexpected( tk ) : Dynamic {
		error(EUnexpected(tokenString(tk)),tokenMin,tokenMax);
		return null;
	}

	inline function push(tk) {
		tokens.push( { t : tk, min : tokenMin, max : tokenMax } );
		tokenMin = oldTokenMin;
		tokenMax = oldTokenMax;
	}

	inline function ensure(tk) {
		var t = token();
		if( t != tk ) unexpected(t);
	}

	inline function ensureToken(tk) {
		var t = token();
		if( !Type.enumEq(t,tk) ) unexpected(t);
	}

	function maybe(tk) {
		var t = token();
		if( Type.enumEq(t, tk) )
			return true;
		push(t);
		return false;
	}

	function getIdent(?thr = true) {
		var tk = token();
		switch( tk ) {
		case TId(id): return id;
		default:
			if(thr)
			unexpected(tk);
			return null;
		}
	}

	inline function expr(e:Expr3LL) {
		return e.expr;
	}

	inline function pmin(e:Expr3LL) {
		return e == null ? 0 : e.pmin;
	}

	inline function pmax(e:Expr3LL) {
		return e == null ? 0 : e.pmax;
	}

	inline function mk(e,?pmin,?pmax) : Expr3LL {
		if( e == null ) return null;
		if( pmin == null ) pmin = tokenMin;
		if( pmax == null ) pmax = tokenMax;
		return { expr : e, pmin : pmin, pmax : pmax, origin : origin, line : line };
	}

	function isBlock(e) {
		if( e == null ) return false;
		return switch( expr(e) ) {	
		case EArrayDecl(_): true;
		case EConst(_): return true;
		case ECall(e,_): if (e != null) isBlock(e) else false;
		case EIdent(_): return true;
		case EBlock(_), EObject(_), ESwitch(_): true;
		case EFunction(_,e,_): isBlock(e);
		case ELocal(_, e): e != null ? isBlock(e) : false;
		case EIf(_,_,_,__): true;
		case EBinop(_,_,e): isBlock(e);
		case EUnop(_,prefix,e): !prefix && isBlock(e);
		case EWhile(_,_): true;
		case ERepeatUntil(_,e): true;
		case EGenericFor(_,_,_) | ENumericFor(_,_,_,_,_): true;
		case EReturn(e): e != null && isBlock(e);
		case ETry(_,_,_,e): isBlock(e);
		case EMeta(_,_): true;
		case ENew(_,_): return true;
		default: false;
		}
	}

	function parseFullExpr( exprs : Array<Expr3LL> ) {
		var e = parseExpr();
		exprs.push(e);

		var tk = token();
		if( tk != TStatement && tk != TEof ) {
			if( isBlock(e) )
				push(tk);
			else
				unexpected(tk);
		}
	}

	function parseExpr() : Expr3LL {
		var tk = token();
		var p1 = tokenMin;
		switch( tk ) {
		case TId(id):
			var e = parseStructure(id);
			if( e == null )
				e = mk(EIdent(id));
			
			return parseExprNext(e);
		case TConst(c):
			return parseExprNext(mk(EConst(c)));
		case TPOpen:
			tk = token();
			if( tk == TPClose ) {
				ensureToken(TOp("->"));
				var eret = parseExpr();
				return mk(EFunction([], mk(EReturn(eret),p1)), p1);
			}
			push(tk);
			var e = parseExpr();
			tk = token();
			switch( tk ) {
			case TPClose:
				return parseExprNext(mk(EParent(e),p1,tokenMax));
			case _:
			}
			return unexpected(tk);
		case TBrOpen:
			var fl = new Array();
			var isObject = false;
			var a = new Array();
			tk = token();
			while( tk != TBrClose && (tk != TEof) ) {
				push(tk);
				var expr = parseExpr();
				switch expr.expr {
					case EBinop("=", e1, e2):
						switch e1.expr {
							case EIdent(s):
								isObject = true;
								fl.push({ name : s, e : e2 });
								//tk = token();
							case _: //unexpected(tk);
						}
					case _: //throw expr;
				}
				a.push(expr);

				tk = token();
				if( tk == TComma )
					tk = token();
			}
			if (isObject)
				return parseExprNext(mk(EObject(fl),p1));
			else
				return parseExprNext(mk(EArrayDecl(a), p1));
			return null;
		case TOp(op):
			if( op == "-" ) {
				var start = tokenMin;
				var e = parseExpr();
				if( e == null )
					return makeUnop(op,e);
				switch( expr(e) ) {
				case EConst(CInt(i)):
					return mk(EConst(CInt(-i)), start, pmax(e));
				case EConst(CFloat(f)):
					return mk(EConst(CFloat(-f)), start, pmax(e));
				default:
					return makeUnop(op,e);
				}
			}
			if( opPriority.get(op) < 0 )
				return makeUnop(op,parseExpr());
			return unexpected(tk);
		case TBkOpen:
			var a = new Array();
			tk = token();
			while( tk != TBkClose && (tk != TEof) ) {
				push(tk);
				a.push(parseExpr());
				tk = token();
				if( tk == TComma )
					tk = token();
			}
			return parseExprNext(mk(EArrayDecl(a), p1));
		case TMeta(s):
			var args = parseMetaArgs();
			return mk(EMeta(s,args));
		default:
			return unexpected(tk);
		}
	}

	function makeUnop( op, e ) {
		return switch( expr(e) ) {
		case EBinop(bop, e1, e2): mk(EBinop(bop, makeUnop(op, e1), e2), pmin(e1), pmax(e2));
		case ETernary(e1, e2, e3): mk(ETernary(makeUnop(op, e1), e2, e3), pmin(e1), pmax(e3));
		default: mk(EUnop(op,true,e),pmin(e),pmax(e));
		}
	}

	function makeBinop( op, e1, e ) {
		return switch( expr(e) ) {
		case EBinop(op2,e2,e3):
			if( opPriority.get(op) <= opPriority.get(op2) )
				mk(EBinop(op2,makeBinop(op,e1,e2),e3),pmin(e1),pmax(e3));
			else
				mk(EBinop(op, e1, e), pmin(e1), pmax(e));
		case ETernary(e2,e3,e4):
			mk(ETernary(makeBinop(op, e1, e2), e3, e4), pmin(e1), pmax(e));
		default:
			mk(EBinop(op,e1,e),pmin(e1),pmax(e));
		}
	}

	var i = 0;
	var elses = [];
	function parseStructure(id) {
		var p1 = tokenMin;
		switch( id ) {
		case "end":
			if( !inFunc && !inFor && !inIf && !inWhile )
				error(EUnexpected(id));

			return mk(EEnd, p1);
		case "if":
			inIf = true;
			var cond = parseExpr();
			var tk = token();
			var exprs = [];
			var elseif = [];
			var elses = [];

			switch tk {
				case TId("then"):
				case _: unexpected(tk);
			}

			var expr = parseExpr();
			if( expr.expr != EEnd ) {
				exprs.push(expr);
				while( true ) {
					var tk = token();
					push(tk);
					if( tk == TEof )
						break;

					var expr = parseExpr();
					if( expr.expr == EEnd )
						break;
					else if ( Type.enumEq(tk,TId("else")) )
					{
						var expr = parseExpr();
						if( expr.expr != EEnd ) {
							elses.push(expr);
							while( true ) {
								var tk = token();
								push(tk);
								if( tk == TEof )
									break;
								var expr = parseExpr();
								if( expr.expr == EEnd )
									break;
								elses.push(expr);
							}
						}
						this.elses.push(elses);
						break;
					} 
					else if ( Type.enumEq(tk,TId("elseif")) )
					{
						i = 1;
						elseif.push(parseStructure("if"));
						i = 0;
					} 
					else exprs.push(expr);
				}
			}
			var elses = [];
			if( this.elses.length > 0 )
				elses = this.elses.pop();
			return mk(EIf(cond,exprs,elseif,elses));
		case "local":
			var ident = getIdent();
			var tk = token();
			
			var e = null;
			switch (tk)
			{
				case TOp("="): e = parseExpr();
				tk = token();
				switch tk {
					case TStatement:
					case TEof:
					case _: push(tk);
				}
				case TEof:
				default: unexpected(tk);
			}
			return mk(ELocal(ident,e),p1,(e == null) ? tokenMax : pmax(e));
		case "while":
			inWhile = true;
			var econd = parseExpr();
			var tk = token();
			var exprs = [];
			switch tk {
				case TId("do"):
					var expr = parseExpr();
					if( expr.expr != EEnd ) 
						exprs.push(expr);

					while( expr.expr != EEnd ) {
						expr = parseExpr();
						if( expr.expr != EEnd )
							exprs.push(expr); 
					}

					inWhile = false;
					return mk(EWhile(econd,exprs),p1,pmax(exprs[exprs.length - 1]));
				case _: 
					inWhile = false;
					unexpected(tk);
					return null;
			}
		case "repeat":
			var expr = parseExpr();
			var exprs = [];
			if( !Type.enumEq(expr.expr,EIdent("until")) )
				exprs.push(expr);
			
			while( !Type.enumEq(expr.expr,EIdent("until")) ) {
				expr = parseExpr();
				exprs.push(expr);
			}
			var econd = parseExpr();
			return mk(ERepeatUntil(econd, exprs),p1,pmax(exprs[exprs.length - 1]));
		case "for":
			inFor = true;
			var id = getIdent();
			var id2 = null;
			var tk = token();
			switch tk {
				case TComma:
					id2 = getIdent();
					tk = token();

					switch tk {
						case TOp("="):
							error(ECustom("'in' expected near '='"));
						case _:
					}
				case _:
			}
			switch tk {
				case TOp("="):
					var exprs = [];
					var e = parseExpr();
					ensure(TComma);
					var e2 = parseExpr();
					ensure(TComma);
					var e3 = parseExpr();
					var tk = token();
					switch tk {
						case TId("do"): 
							var expr = parseExpr();
							if( expr.expr != EEnd ) {
								exprs.push(expr);	
							}
							while( expr.expr != EEnd ) {
								expr = parseExpr();
								if( expr.expr != EEnd )
									exprs.push(expr);
							}
						case _: unexpected(tk);
					}

					inFor = false;
					return mk(ENumericFor(id,e,e2,e3,exprs),p1);
				case TId("in"):
					var e = parseExpr();
					var exprs = [];
					var tk = token();
					switch tk {
						case TId("do"):
							var expr = parseExpr();
							if( expr.expr != EEnd ) {
								exprs.push(expr);
							}
							while( expr.expr != EEnd ) {
								expr = parseExpr();
								if( expr.expr != EEnd )
									exprs.push(expr);
							}
						case _: unexpected(tk);
					}
					inFor = false;
					return mk(EGenericFor(id,id2,e,exprs));
				case _: return unexpected(tk);
			}
		case "break": 
			if( !inFor && !inWhile )
				unexpected(TId("break"));
			return mk(EBreak);
		case "continue": 
			if( !inFor && !inWhile )
				unexpected(TId("continue"));	
			return mk(EContinue);
		case "function":
			var tk = token();
			var name = null;
			var args = [];
			switch( tk ) {
			case TId(id): 
				name = id;
				var tk = token();
				if( tk != TPOpen )
					unexpected(tk);
			case TPOpen: 
			case _: unexpected(tk);
			}
			var tk = token();
			while( tk != TPClose ) {
				switch tk {
				case TId(s): args.push(s);
				case TComma:
				case _: unexpected(tk);
				}
				tk = token();
			}

			inFunc = true;
			var exprs = [];
			var expr = parseExpr();
			if( expr.expr != EEnd )
				exprs.push(expr);

			while( expr.expr != EEnd ) {
				expr = parseExpr();
				if( expr.expr != EEnd )
					exprs.push(expr);
			}
			
			inFunc = false;
			return mk(EFunction(args, mk(EBlock(exprs)), name), p1, pmax(exprs[exprs.length - 1])); //EFunction();
		case "return":
			var tk = token();
			push(tk);
			var empty = tk == TStatement;
			if( empty )
			return mk(EReturnEmpty);
			var e = try parseExpr() catch(e) null;
			return mk(EReturn(e),p1,if( e == null ) tokenMax else pmax(e));
		default:
			return null;
		}
	}

	function parseExprNext( e1 : Expr3LL ) {
		var tk = token();
		switch( tk ) {
		case TOp(op):
			if( opPriority.get(op) == -1 ) {
				if( isBlock(e1) || switch(expr(e1)) { case EParent(_): true; default: false; } ) {
					push(tk);
					return e1;
				}
				return parseExprNext(mk(EUnop(op,false,e1),pmin(e1)));
			}
			return makeBinop(op,e1,parseExpr());
		case TDoubleDot:
			var field = getIdent();
			var e = parseExprNext(mk(EField(e1,field),pmin(e1)));
			switch e.expr {
				case ECall(e2,params):
					var name = switch e2.expr {
						case EField(v,_): 
							switch v.expr {
								case EIdent(v):
									v;
								case _: null;
							}
						case _: null;	
					}

					if( field != null ) {
						if( field != "new" )
							return mk(ECallSugar(e2, params, field));
						else 
							return mk(ENew(name, params));
					}
					else 
						return null;
				case _:
					error(ECustom("function arguments expected near " + field));
					return null;
			}
		case TDot:
			var field = getIdent();
			return parseExprNext(mk(EField(e1,field),pmin(e1)));
		case TPOpen:
			return parseExprNext(mk(ECall(e1,parseExprList(TPClose)),pmin(e1)));
		case TBkOpen:
			var e2 = parseExpr();
			ensure(TBkClose);
			return parseExprNext(mk(EArray(e1,e2),pmin(e1)));
		case TQuestion:
			var e2 = parseExpr();
			ensure(TDoubleDot);
			var e3 = parseExpr();
			return mk(ETernary(e1,e2,e3),pmin(e1),pmax(e3));
		default:
			if( tk != TStatement )
				push(tk);
			return e1;
		}
	}

	function parsePath() {
		var path = [getIdent()];
		while( true ) {
			var t = token();
			if( t != TDot ) {
				push(t);
				break;
			}
			path.push(getIdent());
		}
		return path;
	}

	
	function parseMetaArgs() {
		var tk = token();
		if( tk != TPOpen ) {
			push(tk);
			return null;
		}
		var args = [];
		tk = token();
		if( tk != TPClose ) {
			push(tk);
			while( true ) {
				args.push(parseExpr());
				switch( token() ) {
				case TComma:
				case TPClose:
					break;
				case tk:
					unexpected(tk);
				}
			}
		}
		return args;
	}

	function parseExprList( etk ) {
		var args = new Array();
		var tk = token();
		if( tk == etk )
			return args;
		push(tk);
		while( true ) {
			args.push(parseExpr());
			tk = token();
			switch( tk ) {
			case TComma:
			default:
				if( tk == etk ) break;
				unexpected(tk);
				break;
			}
		}
		return args;
	}

	// ------------------------ lexing -------------------------------

	inline function readChar() {
		return StringTools.fastCodeAt(input, readPos++);
	}

	function readString( until , ?multiline = false ) {
		var c = 0;
		var b = new StringBuf();
		var esc = false;
		var old = line;
		var s = input;
		var p1 = readPos - 1;
		if( multiline ) until = 93; // ]
		while( true ) {
			var c = readChar();
			if( StringTools.isEof(c) ) {
				line = old;
				if( multiline )
					error(EUnterminatedLongString(old), p1, p1);
				else
					error(EUnterminatedString(s), p1, p1);
				break;
			}
			if( esc ) {
				esc = false;
				switch( c ) {
				case 'n'.code: b.addChar('\n'.code);
				case 'r'.code: b.addChar('\r'.code);
				case 't'.code: b.addChar('\t'.code);
				case "'".code, '"'.code, '\\'.code: b.addChar(c);
				case '/'.code: invalidChar(c);
				case "u".code:
					invalidChar(c);
					var k = 0;
					for( i in 0...4 ) {
						k <<= 4;
						var char = readChar();
						switch( char ) {
						case 48,49,50,51,52,53,54,55,56,57: // 0-9
							k += char - 48;
						case 65,66,67,68,69,70: // A-F
							k += char - 55;
						case 97,98,99,100,101,102: // a-f
							k += char - 87;
						default:
							if( StringTools.isEof(char) ) {
								line = old;
								error(EUnterminatedString(s), p1, p1);
							}
							invalidChar(char);
						}
					}
					b.addChar(k);
				default: invalidChar(c);
				}
			} else if( c == 92 )
				esc = true;
			else if( c == until )
			{
				if( c == 93 )
				{
					c = readChar();
					if( c == 93 )
						break;
					else 
						readPos--;
				}
				else
					break;
			}
			else {
				if( c == 10 ) 
				{
					line++;
					if (!multiline) error(EUnterminatedString(String.fromCharCode(until)));
				}
				b.addChar(c);
			}
		}
		return b.toString();
	}


	function token() {
		var t = tokens.pop();
		if( t != null ) {
			tokenMin = t.min;
			tokenMax = t.max;
			return t.t;
		}
		oldTokenMin = tokenMin;
		oldTokenMax = tokenMax;
		tokenMin = (this.char < 0) ? readPos : readPos - 1;
		var t = _token();
		switch t {
			case TId("not"):
				t = TOp("not");
			case TId("and"):
				t = TOp("and");
			case TId("or"):
				t = TOp("or");
			case _:
		}
		tokenMax = (this.char < 0) ? readPos - 1 : readPos - 2;
		return t;
	}

	function _token() {
		var char;
		if( this.char < 0 )
			char = readChar();
		else {
			char = this.char;
			this.char = -1;
		}
		while( true ) {
			if( StringTools.isEof(char) ) {
				this.char = char;
				return TEof;
			}
			switch( char ) {
			case 0:
				return TEof;
			case 32,9,13: // space, tab, CR
				tokenMin++;
			case 10: line++; // LF
				tokenMin++;
			case 48,49,50,51,52,53,54,55,56,57: // 0...9
				var n = (char - 48) * 1.0;
				var exp = 0.;
				while( true ) {
					char = readChar();
					exp *= 10;
					switch( char ) {
					case 48,49,50,51,52,53,54,55,56,57:
						n = n * 10 + (char - 48);
					case "e".code, "E".code:
						var tk = token();
						var pow : Null<Int> = null;
						switch( tk ) {
						case TConst(CInt(e)): pow = e;
						case TOp("-"):
							tk = token();
							switch( tk ) {
							case TConst(CInt(e)): pow = -e;
							default: push(tk);
							}
						default:
							push(tk);
						}
						if( pow == null )
							invalidChar(char);
						return TConst(CFloat((Math.pow(10, pow) / exp) * n * 10));
					case ".".code:
						if( exp > 0 ) {
							// in case of '0...'
							/*if( exp == 10 && readChar() == ".".code ) {
								push(TOp("..."));
								var i = Std.int(n) & 0xFFFFFFFF;
								return TConst( (i == n) ? CInt(i) : CFloat(n) );
							}*/
							invalidChar(char);
						}
						exp = 1.;
					case "x".code:
						if( n > 0 || exp > 0 )
							invalidChar(char);
						// read hexa
						#if haxe3
						var n = 0;
						while( true ) {
							char = readChar();
							switch( char ) {
							case 48,49,50,51,52,53,54,55,56,57: // 0-9
								n = (n << 4) + char - 48;
							case 65,66,67,68,69,70: // A-F
								n = (n << 4) + (char - 55);
							case 97,98,99,100,101,102: // a-f
								n = (n << 4) + (char - 87);
							default:
								this.char = char;
								return TConst(CInt(n & 0xFFFFFFFF));
							}
						}
						#else
						var n = haxe.Int32.ofInt(0);
						while( true ) {
							char = readChar();
							switch( char ) {
							case 48,49,50,51,52,53,54,55,56,57: // 0-9
								n = haxe.Int32.add(haxe.Int32.shl(n,4), cast (char - 48));
							case 65,66,67,68,69,70: // A-F
								n = haxe.Int32.add(haxe.Int32.shl(n,4), cast (char - 55));
							case 97,98,99,100,101,102: // a-f
								n = haxe.Int32.add(haxe.Int32.shl(n,4), cast (char - 87));
							default:
								this.char = char;
								// we allow to parse hexadecimal Int32 in Neko, but when the value will be
								// evaluated by Interpreter, a failure will occur if no Int32 operation is
								// performed
								var v = try CInt(haxe.Int32.toInt(n)) catch( e : Dynamic ) CInt32(n);
								return TConst(v);
							}
						}
						#end
					default:
						this.char = char;
						var i = Std.int(n);
						return TConst( (exp > 0) ? CFloat(n * 10 / exp) : ((i == n) ? CInt(i) : CFloat(n)) );
					}
				}

			case ";".code: return TStatement;
			case "(".code: return TPOpen;
			case ")".code: return TPClose;
			case ",".code: return TComma;
			case ".".code:
				char = readChar();
				switch( char ) {
				case 48,49,50,51,52,53,54,55,56,57:
					var n = char - 48;
					var exp = 1;
					while( true ) {
						char = readChar();
						exp *= 10;
						switch( char ) {
						case 48,49,50,51,52,53,54,55,56,57:
							n = n * 10 + (char - 48);
						default:
							this.char = char;
							return TConst( CFloat(n/exp) );
						}
					}
				case ".".code:
					return TOp("..");
				default:
					this.char = char;
					return TDot;
				}
			case "{".code: return TBrOpen;
			case "}".code: return TBrClose;
			case "[".code: 
				char = readChar();
				if( char == "[".code ) {
					return TConst( CString(readString(93,true)) );
				}	
				else 
					readPos--;
				return TBkOpen;
			case "]".code: return TBkClose;
			case "'".code, '"'.code: return TConst( CString(readString(char)) );
			case "?".code: 
				char = readChar();
				this.char = char;
				return TQuestion;
			case ":".code: return TDoubleDot;
			case '='.code:
				char = readChar();
				if( char == '='.code )
					return TOp("==");
				else if ( char == '>'.code )
					return TOp("=>");
				
				this.char = char;
				return TOp("=");
			case '@'.code:
				char = readChar();
				if( idents[char] ) {
					var id = String.fromCharCode(char);
					while( true ) {
						char = readChar();
						if( !idents[char] ) {
							this.char = char;
							return TMeta(id);
						}
						id += String.fromCharCode(char);
					}
				}
				invalidChar(char);
			default:
				if( ops[char] ) {
					var op = String.fromCharCode(char);
					while( true ) {
						char = readChar();
						if( StringTools.isEof(char) ) char = 0;
						if( !ops[char] ) {
							this.char = char;
							return TOp(op);
						}
						var pop = op;
						op += String.fromCharCode(char);
						if( !opPriority.exists(op) && opPriority.exists(pop) ) {
							if( op == "--" )
								return tokenComment(char);
							this.char = char;
							return TOp(pop);
						}
					}
				}
				if( idents[char] ) {
					var id = String.fromCharCode(char);
					while( true ) {
						char = readChar();
						if( StringTools.isEof(char) ) char = 0;
						if( !idents[char] ) {
							this.char = char;
							return TId(id);
						}
						id += String.fromCharCode(char);
					}
				}
				invalidChar(char);
			}
			char = readChar();
		}
		return null;
	}

	function tokenComment( char : Int ) {
		var c = '-'.code;
		var s = input;
		if( c == '-'.code ) { // comment
			while( char != '\r'.code && char != '\n'.code ) {
				char = readChar();
				if( StringTools.isEof(char) ) break;
			}
			this.char = char;
			return token();
		}
		this.char = char;
		return TOp('-');
	}

	static function constString( c ) {
		return switch(c) {
		case CInt(v): Std.string(v);
		case CFloat(f): Std.string(f);
		case CString(s): s; // TODO : escape + quote
		#if !haxe3
		case CInt32(v): Std.string(v);
		#end
		}
	}

	public static function tokenString( t ) : String {
		return switch( t ) {
		case TEof: "<eof>";
		case TConst(c): constString(c);
		case TId(s): s;
		case TOp(s): s;
		case TPOpen: "(";
		case TPClose: ")";
		case TBrOpen: "{";
		case TBrClose: "}";
		case TDot: ".";
		case TComma: ",";
		case TStatement: ";";
		case TBkOpen: "[";
		case TBkClose: "]";
		case TQuestion: "?";
		case TDoubleDot: ":";
		case TMeta(s): "@" + s;
		}
	}
}

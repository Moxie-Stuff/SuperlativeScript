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

import haxe.ds.*;
import llua.Expr3LL;
import haxe.Constraints;
import tea.SScript;

using StringTools;

private enum Stop3LL {
	SBreak;
	SContinue;
	SReturn;
}

@:keepSub
@:access(llua.Tools)
@:access(tea.SScript)
class Interp3LL {

	#if haxe3
	var unchangableVars : Map<String,Dynamic>;
	var variables : Map<String,Dynamic>;
	var locals : Map<String,{ r : Dynamic }>;
	var binops : Map<String, Expr3LL -> Expr3LL -> Dynamic >;
	#else
	public var variables : Hash<Dynamic>;
	var locals : Hash<{ r : Dynamic }>;
	var binops : Hash< Expr3LL -> Expr3LL -> Dynamic >;
	#end

	var depth : Int;
	var inTry : Bool;
	var declared : Array<{ n : String, old : { r : Dynamic } }>;
	var returnValue : Dynamic;

	var inFunc:Bool = false;
	var inIf:Bool = false; 
	var inFor:Bool = false;
	var inWhile:Bool = false;

	var specialObject : {obj:Dynamic , ?includeFunctions:Bool , ?exclusions:Array<String>} = {obj : null , includeFunctions: null , exclusions: null };

	var curExpr : Expr3LL;

	var resumeError:Bool;

	var script : SScript;

	function setScr( scr ) script = scr;

	public function new() {
		#if haxe3
		locals = new Map();
		#else
		locals = new Hash();
		#end
		declared = new Array();
		resetVariables();
		initOps();
	}

	private function resetVariables(){
		#if haxe3
		variables = new Map<String,Dynamic>();
		unchangableVars = new Map();
		#else
		variables = new Hash();
		#end
		
		unchangableVars.set("nil",null);
		unchangableVars.set("true",true);
		unchangableVars.set("false",false);
		unchangableVars.set("print", Reflect.makeVarArgs(function(el) {
			var v = el.shift();
			if( v == null ) 
				v = "nil";
			var str = Std.string(v);
			for( i in el )
			{
				var i:Dynamic = i;
				if( i == null ) i = "nil";
				str += "    " + Std.string(i);
			}

			#if lua 
			untyped __define_feature__("use._hx_print", _hx_print(str));
			#elseif sys
			Sys.println(str);
			#elseif js
			if( js.Syntax.typeof(untyped console) != "undefined" && (untyped console).log != null )
				(untyped console).log(str);
			else 
				trace(str);
			#else 
			trace(str);
			#end
		}));
		unchangableVars.set("math", LuaMath);
		unchangableVars.set("tostring", function(s)
		{
			if( s == null )
				s = "nil";

			return Std.string(s);
		});
		unchangableVars.set("tonumber", function(n:Dynamic):Null<Float> {
			if( n == null ) return null;

			if( (n is Int) || (n is Float) ) return n;
			else if ( (n is String) ) return Std.parseFloat(n);
			else return null;
		});
		unchangableVars.set("pcall", Reflect.makeVarArgs(function(el) {
			var f = el.shift();
			if( f != null && Type.typeof(f) != TFunction ) return f;
			if( f == null || Type.typeof(f) != TFunction ) return false; 

			var r:Dynamic = true;
			try Reflect.callMethod(null,f,el) catch (e:Dynamic) r = e;

			return r;
		}));
		unchangableVars.set("error", function(e) {
			var e = new Error3LL(ECustom(Std.string(e)), curExpr.pmin, curExpr.pmax, curExpr.origin, curExpr.line);
			throw e;
			return e;
		});
		unchangableVars.set("string", LuaString);
		unchangableVars.set("pairs", LuaPairs.pairs);
	}

	function initOps() {
		var me = this;
		#if haxe3
		binops = new Map();
		#else
		binops = new Hash();
		#end
		binops.set("+",function(e1,e2) return arithmetic(e1,e2,"+"));
		binops.set("-",function(e1,e2) return arithmetic(e1,e2,"-"));
		binops.set("*",function(e1,e2) return arithmetic(e1,e2,"*"));
		binops.set("/",function(e1,e2) return arithmetic(e1,e2,"/"));
		binops.set("^",function(e1,e2) return arithmetic(e1,e2,"^"));
		binops.set("%",function(e1,e2) return arithmetic(e1,e2,"%"));
		binops.set("<",function(e1,e2) return arithmetic(e1,e2,"<"));
		binops.set(">",function(e1,e2) return arithmetic(e1,e2,">"));
		binops.set("<=",function(e1,e2) return arithmetic(e1,e2,"<="));
		binops.set(">=",function(e1,e2) return arithmetic(e1,e2,">="));
		binops.set("==",function(e1,e2) return me.expr(e1) == me.expr(e2));
		binops.set("~=",function(e1,e2) return me.expr(e1) != me.expr(e2));
		binops.set("and",and);
		binops.set("or",or);
		binops.set("=",assign);
		binops.set('..',doubledot);
	}

	function arithmetic(e1,e2,op) : Dynamic {
		var me = this;
		var wasString1 = false, wasString2 = false;
		var wasTable1 = false, wasTable2 = false;
		var e1:Dynamic = me.expr(e1);
		var e2:Dynamic = me.expr(e2);
		if( e1 != null && e1 is String )
		{
			e1 = Std.parseFloat(e1);
			wasString1 = true;
		}
		else if( e1 != null && ( e1 is Array || e1 is IMap ) )
			wasTable1 = true;
		if( e2 != null && e2 is String )
		{
			e2 = Std.parseFloat(e2);
			wasString2 = true;
		}
		else if( e2 != null && ( e2 is Array || e2 is IMap ) )
			wasTable2 = true;

		if( e1 == null || e2 == null ) {
			switch op {
				case "+", "-", "*", "/", "%", "^":
					if( wasString1 || wasString2 )
						me.error(ECustom("attempt to perform arithmetic on a string value"));
					else if( wasTable1 || wasTable2 )
						me.error(ECustom("attempt to perform arithmetic on a table value"));
					else
						me.error(ECustom("attempt to perform arithmetic on a nil value"));
				case "<", ">", "<=", ">=":
					if( wasString1 || wasString2 )
						me.error(ECustom("attempt to compare number with string"));
					else if( wasTable1 || wasTable2 )
						me.error(ECustom("attempt to compare number with table"));
					else 
						me.error(ECustom("attempt to compare number with nil"));
			}
		}

		return switch op {
			case "+": e1 + e2;
			case "-": e1 - e2;
			case "*": e1 * e2;
			case "/": e1 / e2;
			case "%": e1 % e2;
			case "^": e1 ^ e2;
			case "<": e1 < e2;
			case ">": e1 > e2;
			case ">=": e1 >= e2;
			case "<=": e1 <= e2;
			case _: .0;
		}
	}

	function and(e1,e2) : Dynamic {
		var me = this; 
		var e1 = me.expr(e1);
		var e2 = me.expr(e2);

		if( e1 == null )
			e1 = false;
		if( e2 == null )
			e2 = false;

		if( (e1 is Bool) && (e2 is Bool) ) return e1 && e2;
		else if( (e1 is Bool) && !(e2 is Bool) ) {
			if( e1 == true ) return true;
			else return false;
		}
		else if( !(e1 is Bool) && (e2 is Bool) ) {
			if( e2 == true ) return true;
			else return false;
		}
		else if( !(e1 is Bool) && !(e2 is Bool) ) return e2;

		return false;
	}

	function or(e1,e2) : Dynamic {
		var me = this; 
		var e1 = me.expr(e1);
		var e2 = me.expr(e2);

		if( e1 == null )
			e1 = false;
		if( e2 == null )
			e2 = false;

		if( (e1 is Bool) && (e2 is Bool) ) return e1 || e2;
		else if( (e1 is Bool) && !(e2 is Bool) ) {
			if( e1 == true ) return true;
			else return e2;
		}
		else if( !(e1 is Bool) && (e2 is Bool) ) {
			if( e2 == true ) return true;
			else return e1;
		}
		else if( !(e1 is Bool) && !(e2 is Bool) ) return e1;

		return false;
	}

	function doubledot(e1,e2) : Dynamic {
		var e1 = Std.string(expr(e1));
		var e2 = Std.string(expr(e2));

		return e1 + e2;
	}

	function setVar( name : String, v : Dynamic ) {
		variables.set(name, v);
	}

	function assign( e1 : Expr3LL, e2 : Expr3LL ) : Dynamic {
		var v = expr(e2);
		switch( e1.expr ) {
		case EIdent(id):
			var l = locals.get(id);
			if( l == null )
			{
				setVar(id,v);
			}
			else {
				l.r = v;
			}
		case EField(e,f):
			v = set(expr(e),f,v);
		case EArray(e, index):
			var arr:Dynamic = expr(e);
			var index:Dynamic = expr(index);
			if (isMap(arr)) {
				setMapValue(arr, index, v);
			}
			else {
				arr[index] = v;
			}

		default:
			//error(EInvalidOp("="));
		}
		return v;
	}

	public function execute( expr : Expr3LL ) : Dynamic {
		depth = 0;
		#if haxe3
		locals = new Map();
		#else
		locals = new Hash();
		#end
		declared = new Array();
		var r = exprReturn(expr);
		return r;
	}

	var shouldAbort = false;
	function exprReturn(e) : Dynamic {
		try {
			return expr(e);
		} catch( e : Stop3LL ) {
			switch( e ) {
			case SBreak: throw "Invalid break";
			case SContinue: throw "Invalid continue";
			case SReturn:
				var v = returnValue;
				returnValue = null;
				return v;
			}
		}
		return null;
	}

	function duplicate<T>( h : #if haxe3 Map < String, T > #else Hash<T> #end ) {
		#if haxe3
		var h2 = new Map();
		#else
		var h2 = new Hash();
		#end
		for( k in h.keys() )
			h2.set(k,h.get(k));
		return h2;
	}

	function restore( old : Int ) {
		while( declared.length > old ) {
			var d = declared.pop();
			locals.set(d.n,d.old);
		}
	}

	inline function error(e : ErrorDef3LL , rethrow=false ) : Dynamic {
		if (resumeError)return null;
		var e = new Error3LL(e, curExpr.pmin, curExpr.pmax, curExpr.origin, curExpr.line);
		if( rethrow ) this.rethrow(e) else throw e;
		return null;
	}

	inline function rethrow( e : Dynamic ) {
		#if hl
		hl.Api.rethrow(e);
		#else
		throw e;
		#end
	}

	function resolve( id : String ) : Dynamic {
		if( id == "_G" )
		{
			return new _G(this).thisField;
		}

		if( specialObject != null && specialObject.obj != null )
		{
			var field = Reflect.getProperty(specialObject.obj,id);
			if( field != null && (specialObject.includeFunctions || Type.typeof(field) != TFunction) && (specialObject.exclusions == null || !specialObject.exclusions.contains(id)) )
				return field;
		}
		
		var u = unchangableVars.get(id);
		if( u != null )
			return u;

		var l = locals.get(id);
		if( l != null )
			return l.r;
		var v = variables.get(id);	
		if( v==null && !variables.exists(id) )
			return null;
		return v;
	}

	public function expr( e : Expr3LL ) : Dynamic {
		curExpr = e;
		var e = e.expr;
		switch( e ) {
		case EEnd:
			if( !inFunc && !inFor && !inIf && !inWhile )
				error(EUnexpected("end"));

			return null;
		case EConst(c):
			switch( c ) {
			case CInt(v): return v;
			case CFloat(f): return f;
			case CString(s): return s;
			#if !haxe3
			case CInt32(v): return v;
			#end
			}
		case EIdent(id):
			return resolve(id);
		case ELocal(n,e):
			var expr1 : Dynamic = e == null ? null : expr(e);
			declared.push({ n : n, old : locals.get(n) });
			locals.set(n,{ r : expr1 });
			return null;
		case EParent(e):
			return expr(e);
		case EBlock(exprs):
			var old = declared.length;
			var v = null;
			for( e in exprs ) {
				if( !shouldAbort )
				{
					v = expr(e);
				}
				else 
				{
					shouldAbort = false;
					restore(old);
					break;
				}
			}
			restore(old);
			return v;
		case EField(e,f):
			return get(expr(e),f);
		case EBinop(op,e1,e2):
			var fop = binops.get(op);
			if( fop == null ) error(EInvalidOp(op));
			return fop(e1,e2);
		case EUnop(op,prefix,e):
			switch(op) {
			case "not":
				var e = expr(e); 
				if( e == null )
					return true;
				else if( e == false )
					return true;
				
				return false;
			case "-":
				return -expr(e);
			default:
				error(EInvalidOp(op));
			}
		case ECall(e,params):
			var args = new Array();
			for( p in params )
				args.push(expr(p));
			
			switch( e.expr ) {
			case EField(e,f):
				var obj = expr(e);
				if( obj == null ) error(EInvalidAccess(f));
				return fcall(obj,f,args);
			default:
				var expr = expr(e);
				if( expr == null )
					error(ECallNilValue(switch e.expr {
						case EIdent(v): v;
						case _: null;
					}));
				return call(null,expr,args);
			}
		case ECallSugar(e,params,f):
			var copyPar = [];
			var exprParams = [];
			var field = switch e.expr {
				case EField(e,_): e;
				case _: null;
			}
 			var e = expr(e);
			for( i in params )
				exprParams.push(expr(i));

			copyPar = exprParams.copy();
			exprParams.push(expr(field));

			var ret = try call(null,e,exprParams) catch (e) {
				if( f != null && field != null ){
					var e = exprParams[exprParams.length - 1];
					Reflect.callMethod(null, Reflect.getProperty(e,f), copyPar);
					return e;
				}
				else return null;
			}
			return ret;
		case EIf(econd,e1,e2,e3):
			var r = null;
			inIf = true;
			var cond = expr(econd);
			if( cond != null && cond != false ) {
				for( i in e1 )
					r = expr(i);
			}
			else 
			{ 
				for( i in e2 ) r = expr(i);
				if( cond == null || cond == false )
					for( i in e3 )
						r = expr(i);
			}
			return r;
		case EWhile(econd,e):
			inWhile = true;
			whileLoop(econd,e);
			inFor = false;
			return null;
		case ERepeatUntil(cond,e):
			whileLoop(cond,e);
			return null;
		case EGenericFor(v,v2,it,e):
			inFor = true;
			forLoop(v,v2,it,e);
			inFor = false;
			return null;
		case ENumericFor(v,vl,min,max,e):
			inFor = true;
			forNumLoop(v,vl,min,max,e);
			inFor = false;
			return null;
		case EBreak:
			throw SBreak;
		case EContinue:
			throw SContinue;
		case EReturn(e):
			returnValue = e == null ? null : expr(e);
			throw SReturn;
		case EReturnEmpty: 
			if(inFunc) {
				shouldAbort = true;
				return null;
			} else 
			return error(EUnexpected("return"));
		case EFunction(params,fexpr,name):
			var capturedLocals = duplicate(locals);
			var me = this;
			var f = function(args:Array<Dynamic>) 
			{		
				inFunc = true;	
				var old = me.locals, depth = me.depth;
				me.depth++;
				me.locals = me.duplicate(capturedLocals);
				for( i in 0...params.length )
					me.locals.set(params[i],{ r : args[i] });
				var r = null;
				var oldDecl = declared.length;
				if( inTry )
					try {
						r = me.exprReturn(fexpr);
					} catch( e : Dynamic ) {
						me.locals = old;
						me.depth = depth;
						#if neko
						neko.Lib.rethrow(e);
						#else
						throw e;
						#end
					}
				else{
					r = me.exprReturn(fexpr);
				}
				restore(oldDecl);
				me.locals = old;
				me.depth = depth;
				inFunc = false;
				return r;
			};
			var f = Reflect.makeVarArgs(f);
			if( name != null ) {
				if( depth == 0 ) {
					// global function
					unchangableVars.set(name, f);
				} else {
					// function-in-function is a local function
					declared.push( { n : name, old : locals.get(name) } );
					var ref = { r : f };
					locals.set(name, ref);
					capturedLocals.set(name, ref); // allow self-recursion
				}
			}
			return f;
		case EArrayDecl(arr):
			if (arr.length > 0 && arr[0].expr.match(EBinop("=>", _))) {
				var isAllString:Bool = true;
				var isAllInt:Bool = true;
				var isAllObject:Bool = true;
				var isAllEnum:Bool = true;
				var keys:Array<Dynamic> = [];
				var values:Array<Dynamic> = [];
				for (e in arr) {
					switch(e.expr) {
						case EBinop("=>", eKey, eValue): {
							var key:Dynamic = expr(eKey);
							var value:Dynamic = expr(eValue);
							isAllString = isAllString && (key is String);
							isAllInt = isAllInt && (key is Int);
							isAllObject = isAllObject && Reflect.isObject(key);
							isAllEnum = isAllEnum && Reflect.isEnumValue(key);
							keys.push(key);
							values.push(value);
						}
						default: throw("=> expected");
					}
				}
				var map:Dynamic = {
					if (isAllInt) new haxe.ds.IntMap<Dynamic>();
					else if (isAllString) new haxe.ds.StringMap<Dynamic>();
					else if (isAllEnum) new haxe.ds.EnumValueMap<Dynamic, Dynamic>();
					else if (isAllObject) new haxe.ds.ObjectMap<Dynamic, Dynamic>();
					else new Map<Dynamic, Dynamic>();
				}
				for (n in 0...keys.length) {
					setMapValue(map, keys[n], values[n]);
				}
				return map;
			}
			else {
				var a = new Array();
				for ( e in arr ) {
					a.push(expr(e));
				}
				return a;
			}
		case EArray(e, index):
			var arr:Dynamic = expr(e);
			var index:Dynamic = expr(index);
			if (isMap(arr)) {
				return getMapValue(arr, index);
			}
			else {
				return arr[index];
			}
		case ENew(cl,params):
			var a = new Array();
			for( e in params )
				a.push(expr(e));
			return cnew(cl,a);
		case EThrow(e):
			throw expr(e);
		case ETry(e,n,_,ecatch):
			var old = declared.length;
			var oldTry = inTry;
			try {
				inTry = true;
				var v : Dynamic = expr(e);
				restore(old);
				inTry = oldTry;
				return v;
			} catch( err : Stop3LL ) {
				inTry = oldTry;
				throw err;
			} catch( err : Dynamic ) {
				// restore vars
				restore(old);
				inTry = oldTry;
				// declare 'v'
				declared.push({ n : n, old : locals.get(n) });
				locals.set(n,{ r : err });
				var v : Dynamic = expr(ecatch);
				restore(old);
				return v;
			}
		case EObject(fl):
			var o = {};
			for( f in fl )
				set(o,f.name,expr(f.e));
			return o;
		case ETernary(econd,e1,e2):
			var e = expr(econd);
			return if( e != null && e != false ) expr(e1) else expr(e2);
		case ESwitch(e, cases, def):
			var val : Dynamic = expr(e);
			var match = false;
			for( c in cases ) {
				for( v in c.values )
				{
					if( ( !Type.enumEq(v.expr,EIdent("_")) && expr(v) == val ) && ( c.ifExpr == null || expr(c.ifExpr) == true ) ) {
						match = true;
						break;
					}
				}
				if( match ) {
					val = expr(c.expr);
					break;
				}
			}
			if( !match )
				val = def == null ? null : expr(def);
			return val;
		case EMeta(n,args):
			if( n == "force" )
			{
				var arg = args[0];
				if( arg == null )
					error(EUnexpected(Parser3LL.tokenString(TMeta(n))));
			}
			else error(EUnexpected(n));
		case ECheckType(e,_):
			return expr(e);
		}
		return null;
	}

	function doWhileLoop(econd,e) {
		var old = declared.length;
		do {
			try {
				expr(e);
			} catch( err : Stop3LL ) {
				switch(err) {
				case SContinue:
				case SBreak: break;
				case SReturn: throw err;
				}
			}
		}
		while( ![null, false].contains(expr(econd)) );
		restore(old);
	}

	function whileLoop(econd,e) {
		var old = declared.length;
		var e:Array<Expr3LL> = e;
		while( ![null, false].contains(expr(econd)) ) {
			try {
				for( e in e ) expr(e);
			} catch( err : Stop3LL ) {
				switch(err) {
				case SContinue:
				case SBreak: break;
				case SReturn: throw err;
				}
			}
		}
		restore(old);
	}

	function makeIterator( v : Dynamic ) : Iterator<Dynamic> {
		#if ((flash && !flash9) || (php && !php7 && haxe_ver < '4.0.0'))
		if ( v.iterator != null ) v = v.iterator();
		#else
		if ( v.iterator != null ) try v = v.iterator() catch( e : Dynamic ) {};
		#end
		if( v.hasNext == null || v.next == null ) error(EInvalidIterator(v));
		return cast v;
	}

	function forNumLoop(v,vl,min,max,e) {
		var old = declared.length;
		declared.push({ n : v , old : locals.get(v) });
		var vl:Null<Int> = expr(vl);
		if( vl == null ) error(ECustom("bad 'for' initial value (number expected, got nil)"));
		var min:Null<Int> = expr(min); 
		if( min == null ) error(ECustom("bad 'for' limit (number expected, got nil)"));
		var max:Null<Int> = expr(max);
		if( max == null ) error(ECustom("bad 'for' step (number expected, got nil)"));
		if( max == 0 ) error(ECustom("'for' step is zero"));

		var it = new LuaIterator(vl, min, max);
		var e:Array<Expr3LL> = e;
		while( it.hasNext() ) {
			locals.set(v, { r : it.next() });
			try {
				for( e in e ) expr(e);
			} catch( err : Stop3LL ) {
				switch( err ) {
				case SContinue:
				case SBreak: break;
				case SReturn: throw err;
				}
			}
		}
		var e:Array<Expr3LL> = e;
	}

	function forLoop(n,n2,it,e) {
		var old = declared.length;
		declared.push({ n : n, old : locals.get(n) });
		if( n2 != null )
			declared.push({ n : n2, old : locals.get(n2) });
		var it = makeIterator(expr(it));
		var e:Array<Expr3LL> = e;
		while( it.hasNext() ) {
			locals.set(n,{ r : it.next() });
			try {
				for( e in e ) expr(e);
			} catch( err : Stop3LL ) {
				switch( err ) {
				case SContinue:
				case SBreak: break;
				case SReturn: throw err;
				}
			}
			if( n2 != null )
				locals.set(n2,{ r : locals.get(n2).r++ });
		}
		restore(old);
	}

	static inline function isMap(o:Dynamic):Bool {
		var classes:Array<Dynamic> = ["Map", "StringMap", "IntMap", "ObjectMap", "HashMap", "EnumValueMap", "WeakMap"];
		if (classes.contains(o))
			return true;

		return Std.isOfType(o, IMap);
	}

	inline function getMapValue(map:Dynamic, key:Dynamic):Dynamic {
		return cast(map, haxe.Constraints.IMap<Dynamic, Dynamic>).get(key);
	}

	inline function setMapValue(map:Dynamic, key:Dynamic, value:Dynamic):Void {
		cast(map, haxe.Constraints.IMap<Dynamic, Dynamic>).set(key, value);
	}

	function get( o : Dynamic, f : String ) : Dynamic {
		if ( o == null ) error(EInvalidAccess(f));
		return {
			if( o is String && Reflect.hasField(LuaString,f) )
			{
				return Reflect.getProperty(LuaString, f);
			}

			return Reflect.getProperty(o,f);
		}
	}

	function set( o : Dynamic, f : String, v : Dynamic ) : Dynamic {
		if( o == null ) error(EInvalidAccess(f));
		Reflect.setProperty(o,f,v);
		return v;
	}

	function fcall( o : Dynamic, f : String, args : Array<Dynamic>) : Dynamic {
		return call(o, get(o, f), args);
	}

	function call( o : Dynamic, f : Dynamic, args : Array<Dynamic>) : Dynamic {
		return Reflect.callMethod(o,f,args);
	}

	function cnew( cl : String, args : Array<Dynamic> ) : Dynamic {
		var c : Dynamic = try resolve(cl) catch(e) null;
		if( c == null ) c = Type.resolveClass(cl);
		if( c == null ) error(EInvalidAccess(cl));

		return Type.createInstance(c,args);
	}
}

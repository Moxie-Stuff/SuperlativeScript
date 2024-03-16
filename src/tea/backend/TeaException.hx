package tea.backend;

import haxe.Exception;

class TeaException
{
    var superlativeException:Exception;
    var luaException:Exception;

    /**
		Exception message.
	**/
    public var message(get, never):String;
    
    public function new(luaException, superlativeException)
    {
        this.luaException = luaException;
        this.superlativeException = superlativeException;
    }

    function get_message():String 
    {
        var s = null;
        if (superlativeException != null) 
            s = "SScript Error: " + superlativeException.message;
        var s2 = null;
        if (luaException != null)
            s2 = "3LLua Error: " + luaException.message;

        var str = null;
        if (s != null && s2 != null)
            str = s + "\n------------------------------------\n" + s2;
        else if (s != null)
            str = s;
        else
            str = s2;
        return str;
    }

    /**
		Detailed exception description.

		Includes message, stack and the chain of previous exceptions (if set).
	**/
    public function details():String
    {
        var s = null;
        if (superlativeException != null) 
            s = "SScript Error: " + superlativeException.details();
        var s2 = null;
        if (luaException != null)
            s2 = "3LLua Error: " + luaException.details();

        var str = null;
        if (s != null && s2 != null)
            str = s + "\n------------------------------------\n" + s2;
        else if (s != null)
            str = s;
        else
            str = s2;
        return str;
    }

    inline function toString():String 
        return message;
}
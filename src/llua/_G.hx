package llua;

import tea.SScript;

@:access(llua.Interp3LL)
class _G 
{
    public var thisField:Map<String, Dynamic>;

    public function new(lua:Interp3LL)
    {
        thisField = [];

        for (i => k in lua.variables) 
        {
            thisField[i] = k;
        }
        for (i => k in lua.unchangableVars) 
        {
            thisField[i] = k;
        }
        #if THREELLUA
        for (i => k in SScript.global3llVariables) 
        {
            thisField[i] = k;
        }
        #end
        for (i => k in lua.locals)
        {
            thisField[i] = k.r;
        }
        
        lua = null;
    }

    inline function toString():String
        return "table";
}
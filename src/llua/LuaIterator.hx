package llua;

class LuaIterator 
{
    public var min:Int;
    public var max:Int;
    public var increment:Int;

    public var first(default, null):Bool = true;

    public function new(min:Int, max:Int, increment:Int)
    {
        this.min = min;
        this.max = max;
        this.increment = increment;
    }

    public function hasNext():Bool 
    {
        if (increment < 0)
            return min > max;
        else 
            return max > min;
    }

    public function next():Int
	{
        if (first)
        {
            first = false;
            return min;
        }
        
		return min += increment;
	}

    public function iterator():Iterator<Int>
    {
        return cast this;
    }
}
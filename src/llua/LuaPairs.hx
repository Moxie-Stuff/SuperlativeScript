package llua;

import haxe.iterators.MapKeyValueIterator;

class LuaPairs 
{
    var i:Int = 0;
    var array:Array<Dynamic>;
    var map:Map<Dynamic, Dynamic>;

    public function new() {}

    public static function pairs(v:Dynamic):LuaPairs
    {
        var pair = new LuaPairs();
        if (v is Array)
        {
            pair.array = v;
            return pair;
        }
        else if (v is haxe.Constraints.IMap)
        {
            pair.map = v;
            return pair;
        }
        else if (v is Dynamic)
        {
            var map = new Map<String, Dynamic>();
            for (i in Reflect.fields(v))
            {
                map.set(i, Reflect.getProperty(v, i)); 
            }
            pair.map = map;
            return pair;
        }
    
        return null;
    }

    public function hasNext():Bool
    {
        if (array != null)
            return i < array.length;

        return false;
    }

    public function next():Dynamic
    {
        if (array != null)
            return array[i++];
    
        return null;
    }

    public function iterator():Dynamic
    {
        if (array != null)
            return this;
        else if (map != null)
            return new MapKeyValueIterator(map);

        return null;
    }
}
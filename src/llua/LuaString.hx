package llua;

class LuaString
{
    public static function gsub(string:String, replace:String, sub:String, ?count:Int) 
    {
        if (count == null || count < 1 || string.indexOf(replace) == -1)
            return StringTools.replace(string, replace, sub);
        else 
        {
            var split = string.split(replace);
           	var str = "";
          
          	if (count >= split.length)
              count = split.length - 1;

          	for (i in 0...count)
			    str += split[i] + sub;
          	for (i in 0...count)
              split.shift();

          	return str + split.join(replace);
        }
    }
}
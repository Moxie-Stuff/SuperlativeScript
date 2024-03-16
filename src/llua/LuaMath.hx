package llua;

class LuaMath 
{
    public static var pi(default, never) = Math.PI;

    public static var huge(default, never) = 1 / 0;
    public static var NaN(default, never) = Math.NaN;
    public static var POSITIVE_INFINITY(default, never) = abs(huge);
    public static var NEGATIVE_INFINITY(default, never) = -abs(huge);

    public static function abs(x) return Math.abs(x);
    public static function acos(x) return Math.acos(x);
    public static function asin(x) return Math.asin(x);
    public static function atan(x) return Math.atan(x);
    public static function atan2(y, x) return Math.atan2(y, x);
    public static function ceil(x) return Math.ceil(x);
    public static function cos(x) return Math.cos(x);
    public static function sin(x) return Math.sin(x);
    public static function cosh(x) return (Math.exp(x) + Math.exp(-x)) / 2;
    public static function sinh(x) return (Math.exp(x) - Math.exp(-x)) / 2;

    public static function floor(x) return Math.floor(x);
    public static function log(x) return Math.log(x);
    public static function max(y, x) return Math.max(y, x);
    public static function min(y, x) return Math.min(y, x);
    public static function pow(x, exp) return Math.pow(x, exp);
    public static function sqrt(x) return Math.sqrt(x);
    public static function tan(x) return Math.tan(x);

    public static function random(?x, ?y) {
        if (x == null && y == null)
            return Math.random();
        else if (x != null) {
            if (y == null) {
                var r = Std.random(0x7FFFFFFF);
                if (r < x)
                    r = x;
                return r;
            }
            else {
                var r = Std.random(y);
                if (r < x)
                    r = x;
                return r;
            }
        }
        else return 0;
    }
}
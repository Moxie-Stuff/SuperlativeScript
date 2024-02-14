

![TeaLogo](https://i.hizliresim.com/3o2yt2d.png)

# SScript

SuperlativeScript is an easy to use Haxe script tool that aims to be simple while supporting all Haxe structures by Tahir and Gabi. It aims to be like native Haxe while staying easy to use.

## Contribution
If you have an issue with SuperlativeScript or have a suggestion, you can always open an issue here. However, pull requests are NOT welcome and will be ignored.

## Installation
`haxelib install SScript`

Enter this command in command prompt to get the latest release from Haxe library.

After installing SuperlativeScript, don't forget to add it to your Haxe project.

------------

### OpenFL projects
Add this to `Project.xml` to add SuperlativeScript to your OpenFL project:
```xml
<haxelib name="SScript"/>
```
### Haxe Projects
Add this to `build.hxml` to add SuperlativeScript to your Haxe build.
```hxml
-lib SScript
```

## Usage
To use SuperlativeScript, you will need a file or a script. Using a file is recommended.

### Using without a file
```haxe
var script:tea.SScript = {}; // Create a new SuperlativeScript class
script.doString("
	function returnRandom():Float
		return Math.random() * 100;
"); // Implement the script
var call = script.call('returnRandom');
var randomNumber:Float = call.returnValue; // Access the returned value with returnValue
```

### Using with a file
```haxe
var script:tea.SScript = new tea.SScript("script.hx"); // Has the same contents with the script above
var randomNumber:Float = script.call('returnRandom').returnValue;
```

## Classes
With SuperlativeScript 10.0.618, classes are supported in teas and can be accessed from other teas.

Example:
```haxe
class Main {
	static function main()
	{
		var script = new tea.SScript();
		script.doString("
				class ScriptClass {
					public static function returnMinus(e:Int) {
						return -e;
					}
				}
		");

		var scriptTwo = new tea.SScript();
		script.doString("
			trace(ScriptClass.returnMinus(1)); // -1
		");
	}
}
```

Teas with class(es) should be initialized first to be accessible to other teas.
If a Tea Class is tried to be accessed without it being initialized, it will throw an exception.

#### Limitations 
Extending is not supported, so it is not possible to create a real class from a Tea Class.
Only static variables and functions are allowed in Tea Classes.

If a Tea contains a class, it cannot have any other expressions other than classes. For example, this script is not valid.
```haxe
class ScriptClass {

}	
trace(1); // Exception: Unexpected trace
```

## Reworked Function Arguments
Function arguments have been reworked, so optional arguments will work like native Haxe.

Example:
```haxe
function add(a:Int, ?b:Int = 1) 
{
	return a + b;
}
trace(add()); // Exception: Invalid number of parameters. Got 0, required 1 for function 'add'
trace(add(0)) // 1 
trace(add(0, 2)) // 2
```

## Variable initialization
Initialization order is this:
- Package
- Imports
- Classes 
- Functions and variables (if there are no classes) 
- Other (if there are no classes)

This means you can use functions after creating a variable, for example:
```haxe
trace(a);
var a = 1;
```

## Using Haxe 4.3.0 Syntaxes
SuperlativeScript supports both `?.` and `??` syntaxes including `??=`.

```haxe
import tea.SScript;
class Main 
{
	static function main()
	{
		var script:SScript = {};
		script.doString("
			var string:String = null;
			trace(string.length); // Throws an error
			trace(string?.length); // Doesn't throw an error and returns null
			trace(string ?? 'ss'); // Returns 'ss';
			trace(string ??= 'ss'); // Returns 'ss' and assigns it to `string` variable
		");
	}
}
```

## Extending SuperlativeScript
You can create a class extending SuperlativeScript to customize it better.
```haxe
class SScriptEx extends tea.SScript
{  
	override function preset():Void
	{
		super.preset();
		
		// Only use 'set', 'setClass' or 'setClassString' in preset
		// Macro classes are not allowed to be set
		setClass(StringTools);
		set('NaN', Math.NaN);
		setClassString('sys.io.File');
	}
}
```
Extend other functions only if you know what you're doing.

## Calling Methods from Tea's
You can call methods and receive their return value from Tea's using `call` function.
It needs one obligatory argument (function name) and one optional argument (function arguments array).

using `call` will return a structure that contains the return value, if calling has been successful, exceptions if it did not, called function name and script file name of the Tea.

Example:
```haxe
var tea:tea.SScript = {};
tea.doString('
	function method()
	{
		return 2 + 2;
	}
');
var call = tea.call('method');
trace(call.returnValue); // 4

tea.doString('
	function method()
	{
		var num:Int = 1.1;
		return num;
	}
')

var call = tea.call('method');
trace(call.returnValue, call.exceptions[0]); // null, Float should be Int
```

## Global Variables
With SuperlativeScript, you can set variables to all running Tea's.
Example:

```haxe
var tea:tea.SScript = {};
tea.set('variable', 1);
tea.doString('
	function returnVar()
	{
		return variable + variable2;
	}
');

tea.SScript.globalVariables.set('variable2', 2);
trace(tea.call('returnVar').returnValue); // 3
```

Variables from `globalVariables` can be changed in script. 
If you do not want this, use `strictGlobalVariables` instead. They will act as a final and cannot be changed in script.

## Special Object
Special object is an object that'll get checked if a variable is not found in a Tea.
A special object cannot be a basic type like Int, Float, String, Array and Bool.

Special objects are useful for OpenFL and Flixel states.

Example:
```haxe
import tea.SScript;

class PlayState extends flixel.FlxState 
{
	var sprite:flixel.FlxSprite;
	override function create()
	{
		sprite = new flixel.FlxSprite();

		var newScript:SScript = new SScript();
		newScript.setSpecialObject(this);
		newScript.doString("sprite.visible = false;");
	}
}
```
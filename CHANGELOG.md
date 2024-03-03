# 11.0.618 Final
- Added Enum Abstract support (Check README.md)
- Completely reworked import system to be faster and more stable
- Completely reworked function arguments
- Added multiline error messages
- The classes of a script now gets destroyed when it gets destroyed
- Custom origins are now unique and cannot be used twice


# 10.1.618
- Fixed variable initialization order
- Fixed function arguments
- Moved `lastReportedCallTime` to call sugars, now accessible with `lastReportedTime`
- Fixed typos 

# 10.0.618
- Added class support
- Added string interpolation
- Added `public` as a shortcut to set global variables in scripts
- Removed StringTools support
- Reworked functions
- Reworked finals
- Reworked variable initialization
- Added better check to if, for and while expressions
- Reworked global variables
- Added `setAsFinal` option to `set`
- Removed useless checks
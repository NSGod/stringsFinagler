stringsFinagler
=====================
For OS X 10.10+  
Written in Swift 2.2  

`stringsFinagler` is wrapper around the `genstrings` tool, used to generate `Localizable.strings` files for targets in an Xcode project.

When given a directory, and the `-R` option is used, `stringsFinagler` will search all subdirectories for `*.c`, `*.m`, `*.mm`, and `*.swift` files which contain the `NSLocalizedString` macro (or the substitute macro specified by the `-s` flag), and pass them on to `genstrings`. The output `.strings` files will be aggregate (adding to any existing strings in the .strings file if it exists).

For best results, pass all of the directories or file paths for one specific target, and assure that there are no existing `.strings` in the output directory. This will result in a `Localizable.strings` file which is sorted alphabetically and has no duplicates.

	Usage: stringsFinagler [OPTIONS] [files ...]
	
	Options:
	  -R                    recurse into subdirectories
	  -s substring          substitute 'substring' for NSLocalizedString.
	  -o dir                place output files in 'dir'.
	  -d --defaultComments  automatically compensate for use of Localized("string")
	                          without the `comment:` parameter.
	  -h --help             show this help.
	  -v --version          show version info and exit.
  
  
***
#### Examples:

    stringsFinagler -R -o ~/Strings MDDirectory/MDProject
   
<p style="margin:0 2em 4em 2em;">Search recursively in the `MDDirectory/MDProject` directory for any `*.c`, `*.m`, `*.mm`, and `*.swift` files which contain the default `NSLocalizedString` macro, and generate output at `~/Strings/`.

    stringsFinagler -R -s Localized MDDirectory/MDProject
   
<p style="margin:0 2em 4em 2em;">Search recursively in the `MDDirectory/MDProject` directory for any files which have defined a custom `Localized` macro or function in place of the default `NSLocalizedString()` macro (for example, `Localized("String", comment:"comment")`), and generate output at the default location, `~/Desktop/Strings/`, creating this directory if necessary.

    stringsFinagler -R -d -s Localized MDDirectory/MDProject

<p style="margin:0 2em 1em 2em;">This example does exactly the same thing as the previous example, but automatically compensates for the use of a `Localized` function that doesn't provide a comment. Take, for instance, the following custom localization function:

	@inline(__always) func Localized(key : String, comment aComment: String = "") -> String {
		return NSLocalizedString(key, comment:aComment)
	}  
	
<p style="margin:0 2em 1em 2em;">A developer could then use this function in code without having to provide a comment parameter: for example, `Localized("String")`. However, the `genstrings` tool requires the `comment` parameter to be present in the source files it processes. To automatically compensate for this, pass the `-d` (`--defaultComments`) parameter to `stringsFinagler`. Doing so will cause `stringsFinagler` to create a temporary copy of your source code files in which it replaces all instances of `Localized("String")` usage with the full `Localized("String", comment:"")` form and then pass those files on to `genstrings`.
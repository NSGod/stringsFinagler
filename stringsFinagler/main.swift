//
//  main.swift
//  stringsFinagler
//
//  Created by Mark Douma on 7/10/2016.
//  Copyright © 2016 Mark Douma. All rights reserved.
//

import Foundation

let DefaultOutputDir = "~/Desktop/Strings"

let pathExtensions : Set = ["m", "mm", "c", "swift"]

// this is a hack to get a better form of printing arrays that isn't all on one line
func print(array: [AnyObject], label aLabel: String) {
	var description = "\(aLabel) == \r"
	for object in array {
		description += "    \(object.description)\r"
	}
	print("\(description)")
}

func version() {
	let bundle = NSBundle.mainBundle()
	let bundleVersion = bundle.objectForInfoDictionaryKey(kCFBundleVersionKey as String)!
	let name = bundle.objectForInfoDictionaryKey(kCFBundleNameKey as String)!
	let shortVersion = bundle.objectForInfoDictionaryKey("CFBundleShortVersionString")!
	print("\(name) \(shortVersion) (\(bundleVersion))\n")
}

func usage(isInvalid : Bool = true) {
	if isInvalid == true { print("invalid usage") }
	print("Usage: stringsFinagler [OPTIONS] [files ...]")
	print("")
	print("Options:")
	print("  -R                    recurse into subdirectories")
	print("  -s substring          substitute 'substring' for NSLocalizedString.")
	print("  -o dir                place output files in 'dir'.")
	print("  -d --defaultComments  automatically compensate for use of Localized(\"string\")")
	print("                          without the `comment:` parameter.")
	print("  -h --help             show this help.")
	print("  -v --version          show version info and exit.")
	print("")
}

var tempDir : String! = nil

func revisedPathForItemAtPath(path : String) -> String {
	if tempDir == nil {
		let tempD = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent("com.markdouma.stringsFinagler.XXXXXXXXXX")
		let cs = (tempD as NSString).UTF8String
		let buffer = UnsafeMutablePointer<Int8>(cs)
		tempDir = String.fromCString(mkdtemp(buffer))
		_ = try? NSFileManager.defaultManager().createDirectoryAtURL(NSURL(fileURLWithPath: tempDir), withIntermediateDirectories: true, attributes: nil)
	}
	let templatePath = (tempDir as NSString).stringByAppendingPathComponent((path as NSString).lastPathComponent + ".XXXXXXXXX")
	let buffer = UnsafeMutablePointer<Int8>((templatePath as NSString).UTF8String)
	let revisedPath = String.fromCString(mktemp(buffer))!
	return revisedPath
}


var args = Process.arguments

guard args.count > 1 else {
	usage()
	exit(EXIT_FAILURE)
}


var outputDirectoryPath = (DefaultOutputDir as NSString).stringByExpandingTildeInPath

var substitutionString : String? = nil

_ = args.removeAtIndex(0)

let argsCount = args.count

var options : NSDirectoryEnumerationOptions = [.SkipsHiddenFiles, .SkipsSubdirectoryDescendants]

var paths = [String]()

var defaultComments = false

var i = 0

for (index, value) in args.enumerate() {
	if value == "-v" || value == "--version" {
		version()
		exit(EXIT_SUCCESS)
		
	} else if value == "-h" || value == "--help" {
		usage(false)
		exit(EXIT_SUCCESS)
	} else if value == "-d" || value == "--defaultComments" {
		defaultComments = true
		i += 1
	} else if value == "-R" || value == "-r" {
		options.remove(.SkipsSubdirectoryDescendants)
		i += 1
	} else if value == "-o" {
		if index + 1 < argsCount {
			outputDirectoryPath = args[index + 1]
			i += 2
		}
	} else if value == "-s" {
		if index + 1 < argsCount {
			substitutionString = args[index + 1]
			i += 2
		}
	} else {
		if i == index {
			paths.append(value)
		}
	}
}

print(paths, label: "paths")

guard !paths.isEmpty else {
	usage()
	exit(EXIT_FAILURE)
}

var revisedURLs = [NSURL]()

let fileManager = NSFileManager.defaultManager()

for path in paths {
	let url = NSURL(fileURLWithPath:path)
	
	if let isDir = try? url.resourceValuesForKeys([NSURLIsDirectoryKey])[NSURLIsDirectoryKey]?.boolValue where isDir == true {
		if let enumerator = fileManager.enumeratorAtURL(url, includingPropertiesForKeys:nil, options:options, errorHandler:nil) {
			guard let allItems = enumerator.allObjects as? [NSURL] else { continue }
//			print(allItems, label: "allItems")
			for innerurl in allItems {
				if pathExtensions.contains(innerurl.pathExtension!.lowercaseString) { revisedURLs.append(innerurl) }
			}
		}
		
	} else {
		if pathExtensions.contains(url.pathExtension!.lowercaseString) { revisedURLs.append(url) }
	}
	
}


//print(revisedURLs, label: "revisedURLs")

let subString = substitutionString ?? "NSLocalizedString" 
let subStringP = substitutionString != nil ? substitutionString! + "(" : "NSLocalizedString("

var revisedPaths = [String]()

for itemURL in revisedURLs {
	var encoding : NSStringEncoding = NSUTF8StringEncoding
	if let sourceCodeString = try? NSString(contentsOfURL:itemURL, usedEncoding: &encoding) {
		if sourceCodeString.rangeOfString(subString, options:[.LiteralSearch]).location != NSNotFound { revisedPaths.append(itemURL.path!) }
	}
}

print(revisedPaths, label: "revisedPaths")

guard !revisedPaths.isEmpty else {
	NSLog("NOTICE: no '.strings' files were produced");
	exit(EXIT_SUCCESS)
}

guard let success = try? fileManager.createDirectoryAtURL(NSURL(fileURLWithPath:outputDirectoryPath), withIntermediateDirectories: true, attributes: nil) else {
	fatalError("failed to create output directory at \"\(outputDirectoryPath)\"")
}

if defaultComments == true {
	
	var transRevisedPaths = [String]()
	
	for revisedPath in revisedPaths {
		let transRevisedPath = revisedPathForItemAtPath(revisedPath)
		
		if transRevisedPath != revisedPath {
			_ = try fileManager.copyItemAtPath(revisedPath, toPath: transRevisedPath)
			transRevisedPaths.append(transRevisedPath)
		}
	}
	
	for transRevisedPath in transRevisedPaths {
		var encoding : NSStringEncoding = NSUTF8StringEncoding
		
		if let sourceCodeString = try? String(contentsOfFile: transRevisedPath, usedEncoding: &encoding) {
			var adaptedString = ""
			
			let scanner = NSScanner(string: sourceCodeString)
			scanner.charactersToBeSkipped = NSCharacterSet(charactersInString: "")
			scanner.caseSensitive = true
			
			var scanLocation = 0
			
			var result : NSString? = nil
			var localizedString : NSString? = nil
			
			while scanner.atEnd == false {
				if scanner.scanUpToString(subStringP, intoString: &result) &&
					scanner.scanString(subStringP, intoString: nil) &&
					scanner.scanUpToString("\")", intoString: &localizedString) &&
					scanner.scanString("\")", intoString: nil) {
					
					if result?.length > 0 {
						adaptedString += result! as String
					}
					scanLocation = scanner.scanLocation
					
					adaptedString += subStringP
					
					if let locString = localizedString {
						adaptedString += (locString as String) + "\""
						if locString.rangeOfString(" comment:", options: [.LiteralSearch]).location == NSNotFound {
							adaptedString += ", comment:\"\")"
						} else {
							adaptedString += ")"
						}
					}
				} else {
					adaptedString += (sourceCodeString as NSString).substringFromIndex(scanLocation)
				}
			}
			_ = try? adaptedString.writeToFile(transRevisedPath, atomically: true, encoding: NSUTF8StringEncoding)
		}
	}
	revisedPaths = transRevisedPaths
}


let task = NSTask()
task.launchPath = "/usr/bin/genstrings"

var taskArgs = ["-a"]

if substitutionString != nil {
	taskArgs += ["-s", substitutionString!]
}

taskArgs += ["-o", outputDirectoryPath]
taskArgs += revisedPaths

task.arguments = taskArgs

task.standardOutput = NSPipe()
task.standardError = NSPipe()
task.launch()
task.waitUntilExit()

let data = task.standardOutput!.fileHandleForReading.readDataToEndOfFile()
if data.length > 0 {
	if let string = String(data:data, encoding:NSUTF8StringEncoding) {
		NSLog("standardOutput == \(string)")
	}
}

let errData = task.standardError!.fileHandleForReading.readDataToEndOfFile()
if errData.length > 0 {
	if let stdErrorString = String(data:errData, encoding:NSUTF8StringEncoding) {
		NSLog("standardError == \(stdErrorString)")
	}
}

if !task.running {
	if task.terminationStatus != 0 {
		NSLog("task.terminationStatus == \(task.terminationStatus)")
	}
}

if tempDir != nil { _ = try? fileManager.removeItemAtPath(tempDir) }


exit(EXIT_SUCCESS)






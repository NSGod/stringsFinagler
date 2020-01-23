//
//  main.swift
//  stringsFinagler
//
//  Created by Mark Douma on 7/10/2016.
//  Copyright © 2016 Mark Douma. All rights reserved.
//

import Foundation
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


let DefaultOutputDir = "~/Desktop/Strings"

let pathExtensions : Set = ["m", "mm", "c", "swift"]

// this is a hack to get a better form of printing arrays that isn't all on one line
func print(_ array: [AnyObject], label aLabel: String) {
	var description = "\(aLabel) == \r"
	for object in array {
		description += "    \(object.description)\r"
	}
	print("\(description)")
}

func version() {
	let bundle = Bundle.main
	let bundleVersion = bundle.object(forInfoDictionaryKey: kCFBundleVersionKey as String)!
	let name = bundle.object(forInfoDictionaryKey: kCFBundleNameKey as String)!
	let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString")!
	print("\(name) \(shortVersion) (\(bundleVersion))\n")
}

func usage(_ isInvalid : Bool = true) {
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

func revisedPathForItemAtPath(_ path : String) -> String {
	if tempDir == nil {
		let tempD = (NSTemporaryDirectory() as NSString).appendingPathComponent("com.markdouma.stringsFinagler.XXXXXXXXXX")
		let cs = (tempD as NSString).utf8String
		let buffer = UnsafeMutablePointer<Int8>(mutating: cs)
		tempDir = String(cString: mkdtemp(buffer))
		_ = try? FileManager.default.createDirectory(at: URL(fileURLWithPath: tempDir), withIntermediateDirectories: true, attributes: nil)
	}
	let templatePath = (tempDir as NSString).appendingPathComponent((path as NSString).lastPathComponent + ".XXXXXXXXX")
	let buffer = UnsafeMutablePointer<Int8>(mutating: (templatePath as NSString).utf8String)
	let revisedPath = String(cString: mktemp(buffer))
	return revisedPath
}


var args = CommandLine.arguments

guard args.count > 1 else {
	usage()
	exit(EXIT_FAILURE)
}


var outputDirectoryPath = (DefaultOutputDir as NSString).expandingTildeInPath

var substitutionString : String? = nil

_ = args.remove(at: 0)

let argsCount = args.count

var options : FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsSubdirectoryDescendants]

var paths = [String]()

var defaultComments = false

var i = 0

for (index, value) in args.enumerated() {
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
		options.remove(.skipsSubdirectoryDescendants)
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
			i += 1
		}
	}
}

print(paths as [AnyObject], label: "paths")

guard !paths.isEmpty else {
	usage()
	exit(EXIT_FAILURE)
}

var revisedURLs = [URL]()

let fileManager = FileManager.default

for path in paths {
	let url = URL(fileURLWithPath:path)
	
	if let isDir = try? ((url as NSURL).resourceValues(forKeys: [URLResourceKey.isDirectoryKey])[URLResourceKey.isDirectoryKey] as AnyObject).boolValue, isDir == true {
		if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys:nil, options:options, errorHandler:nil) {
			guard let allItems = enumerator.allObjects as? [URL] else { continue }
//			print(allItems, label: "allItems")
			for innerurl in allItems {
				if pathExtensions.contains(innerurl.pathExtension.lowercased()) { revisedURLs.append(innerurl) }
			}
		}
		
	} else {
		if pathExtensions.contains(url.pathExtension.lowercased()) { revisedURLs.append(url) }
	}
	
}


//print(revisedURLs, label: "revisedURLs")

let subString = substitutionString ?? "NSLocalizedString" 
let subStringP = substitutionString != nil ? substitutionString! + "(" : "NSLocalizedString("

var revisedPaths = [String]()

for itemURL in revisedURLs {
	var encoding : String.Encoding = String.Encoding.utf8
	if let sourceCodeString = try? NSString(contentsOf:itemURL, usedEncoding: &encoding.rawValue) {
		if sourceCodeString.range(of: subString, options:[.literal]).location != NSNotFound { revisedPaths.append(itemURL.path) }
	}
}

print(revisedPaths as [AnyObject], label: "revisedPaths")

guard !revisedPaths.isEmpty else {
	NSLog("NOTICE: no '.strings' files were produced");
	exit(EXIT_SUCCESS)
}

guard let success = try? fileManager.createDirectory(at: URL(fileURLWithPath:outputDirectoryPath), withIntermediateDirectories: true, attributes: nil) else {
	fatalError("failed to create output directory at \"\(outputDirectoryPath)\"")
}

if defaultComments == true {
	
	var transRevisedPaths = [String]()
	
	for revisedPath in revisedPaths {
		let transRevisedPath = revisedPathForItemAtPath(revisedPath)
		
		if transRevisedPath != revisedPath {
			_ = try fileManager.copyItem(atPath: revisedPath, toPath: transRevisedPath)
			transRevisedPaths.append(transRevisedPath)
		}
	}
	
	for transRevisedPath in transRevisedPaths {
		var encoding : String.Encoding = String.Encoding.utf8
		
		if let sourceCodeString = try? String(contentsOfFile: transRevisedPath, usedEncoding: &encoding) {
			var adaptedString = ""
			
			let scanner = Scanner(string: sourceCodeString)
			scanner.charactersToBeSkipped = CharacterSet(charactersIn: "")
			scanner.caseSensitive = true
			
			var scanLocation = 0
			
			var result : NSString? = nil
			var localizedString : NSString? = nil
			
			while scanner.isAtEnd == false {
				if scanner.scanUpTo(subStringP, into: &result) &&
					scanner.scanString(subStringP, into: nil) &&
					scanner.scanUpTo("\")", into: &localizedString) &&
					scanner.scanString("\")", into: nil) {
					
					if result?.length > 0 {
						adaptedString += result! as String
					}
					scanLocation = scanner.scanLocation
					
					adaptedString += subStringP
					
					if let locString = localizedString {
						adaptedString += (locString as String) + "\""
						if locString.range(of: " comment:", options: [.literal]).location == NSNotFound {
							adaptedString += ", comment:\"\")"
						} else {
							adaptedString += ")"
						}
					}
				} else {
					adaptedString += (sourceCodeString as NSString).substring(from: scanLocation)
				}
			}
			_ = try? adaptedString.write(toFile: transRevisedPath, atomically: true, encoding: String.Encoding.utf8)
		}
	}
	revisedPaths = transRevisedPaths
}


let task = Process()
task.launchPath = "/usr/bin/genstrings"

var taskArgs = ["-a"]

if substitutionString != nil {
	taskArgs += ["-s", substitutionString!]
}

taskArgs += ["-o", outputDirectoryPath]
taskArgs += revisedPaths

task.arguments = taskArgs

task.standardOutput = Pipe()
task.standardError = Pipe()
task.launch()
task.waitUntilExit()

let data = (task.standardOutput! as AnyObject).fileHandleForReading.readDataToEndOfFile()
if data.count > 0 {
	if let string = String(data:data, encoding:String.Encoding.utf8) {
		NSLog("standardOutput == \(string)")
	}
}

let errData = (task.standardError! as AnyObject).fileHandleForReading.readDataToEndOfFile()
if errData.count > 0 {
	if let stdErrorString = String(data:errData, encoding:String.Encoding.utf8) {
		NSLog("standardError == \(stdErrorString)")
	}
}

if !task.isRunning {
	if task.terminationStatus != 0 {
		NSLog("task.terminationStatus == \(task.terminationStatus)")
	}
}

if tempDir != nil { _ = try? fileManager.removeItem(atPath: tempDir) }

exit(EXIT_SUCCESS)

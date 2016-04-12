//
//  String+SwimMisc.swift
//  Swim
//
//  Created by Ewan Mellor on 4/8/16.
//
//

import Foundation


private let stringBySanitizingFilenameRE = try! NSRegularExpression(pattern: "\\s*[^]\\w !#$%&'()+,.;=@\\[\\^_`{}~-]+\\s*", options: [])


extension String {
    /**
     - returns: A copy of this string, with runs of any slashes, backslashes
     or unprintable characters replaced with a single space.  Whitespace is
     also trimmed from front and back of each component.  This means that
     the string can be used as a filename, allowing as many "unusual"
     characters as possible.
     */
    var stringBySanitizingFilename: String {
        let s = stringBySanitizingFilenameRE.stringByReplacingMatchesInString(self, options: [], range:NSMakeRange(0, utf16.count), withTemplate: " ")
        let bits = s.componentsSeparatedByString(".")
        let trimmed_bits = bits.map { return $0.trim }
        return trimmed_bits.joinWithSeparator(".")
    }

    var trim: String {
        return stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
    }
}

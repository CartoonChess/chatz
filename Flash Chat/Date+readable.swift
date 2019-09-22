//
//  Date+readable.swift
//  Flash Chat
//
//  Created by Xcode on ’19/09/12.
//  Copyright © 2019 London App Brewery. All rights reserved.
//

import Foundation

extension String {
    func plural(_ count: Int = 0) -> String {
        if count == 1 {
            return self
        }
        return self + "s"
    }
    
    mutating func pluralize(_ count: Int = 0) {
        self = self.plural(count)
    }
}

extension CharacterSet {
    static let vowels = CharacterSet(charactersIn: "aeiou")
}

extension Int {
    func word(useArticle: Bool = false, noun: String = "b") -> String {
        switch self {
        case 0: return "zero"
        case 1:
            if !useArticle {
                return "one"
            } else {
                let consonantArticle = "a"
                let vowelArticle = "an"
                
                // Special cases (manual)
                if noun.starts(with: "hou") {
                    return vowelArticle
                }
                
                // Generic vowel check
                let firstLetter = String(noun.first ?? "b")
                if firstLetter.rangeOfCharacter(from: CharacterSet.vowels) == nil {
                    return consonantArticle
                } else {
                    return vowelArticle
                }
            }
        case 2: return "two"
        case 3: return "three"
        case 4: return "four"
        case 5: return "five"
        case 6: return "six"
        case 7: return "seven"
        case 8: return "eight"
        case 9: return "nine"
        default:
            return String(self)
        }
    }
    
    func of(_ noun: String, useArticle: Bool = false) -> String {
        let count = self.word(useArticle: useArticle, noun: noun)
        let noun = noun.plural(self)
        return "\(count) \(noun)"
    }
}

extension Date {
    private enum ApproximateSeconds {
        static let second = 1.0
        static let minute = 60.0 * second
        static let hour = 60.0 * minute
        static let day = 24.0 * hour
        static let week = 7.0 * day
        static let month = 30.4375 * day
        static let year = 365.25 * day
    }
    
    enum ReadableStyle {
        case normal, elapsed
    }
    
    private func compare(from past: Date, formatter: DateFormatter, style: ReadableStyle = .normal, fuzzy: Bool = false) -> String {
        let calendar = Calendar.current
        let future = self
        
        var differences: [Calendar.Component: Int] = [
            .year: 0,
            .month: 0,
            .day: 0,
            .hour: 0,
            .minute: 0,
            .second: 0
        ]
        
        // Differences as integers
        for difference in differences {
            let component = difference.key
            let futureComponent = calendar.component(component, from: future)
            let pastComponent = calendar.component(component, from: past)
            let difference = futureComponent - pastComponent
            differences[component] = difference
        }
        
        // TODO: Localize everything below here (both language and format)
        // TODO: Options for fuzzy vs. accurate
        // Normal+accurate (current): date + time
        // Normal+fuzzy: "last month" + time?
        // Elapsed+accurate: "three weeks, two days, ten hours ago"???
        // Elapsed+fuzzy (current): "a year and a half ago"
        
        // Format according to fixed, then leave
        if style == .normal {
            let days = differences[.day]
            if days == 0 {
                // Just the time
                formatter.dateStyle = .none
            } else if days == 1 {
                formatter.dateStyle = .none
                let time = formatter.string(from: past)
                return "Yesterday, \(time)"
            }
            
            return formatter.string(from: past)
        }
        
        // Otherwise, let's do elapsed time styling
        
        let differenceInSeconds = abs(Double(future.timeIntervalSince(past)))
        // Past or future?
        var adverb = "ago"
        if future < past { adverb = "from now" }
        
        // Find the largest gap of time
        var biggestDifference: (component: String, amount: Double) = ("second", differenceInSeconds)
        
        switch differenceInSeconds {
        case ..<ApproximateSeconds.minute:
            break
        case ..<ApproximateSeconds.hour:
            biggestDifference = ("minute", differenceInSeconds / ApproximateSeconds.minute)
        case ..<ApproximateSeconds.day:
            biggestDifference = ("hour", differenceInSeconds / ApproximateSeconds.hour)
        case ..<ApproximateSeconds.week:
            biggestDifference = ("day", differenceInSeconds / ApproximateSeconds.day)
        case ..<ApproximateSeconds.month:
            biggestDifference = ("week", differenceInSeconds / ApproximateSeconds.week)
        case ..<ApproximateSeconds.year:
            biggestDifference = ("month", differenceInSeconds / ApproximateSeconds.month)
        default:
            // Years, which we measure with a decimal in order to approximate half-years as well
            biggestDifference = ("year", differenceInSeconds / ApproximateSeconds.year)
        }
        
        // Format
        switch biggestDifference.component {
        case "second":
            let seconds = biggestDifference.amount
            if seconds < 10 {
                return "now"
            } else if seconds <= 45 {
                break
            } else {
                biggestDifference = ("minute", 1)
            }
        case "minute":
            let minutes = biggestDifference.amount
            if minutes <= 25 || (36...55).contains(minutes) {
                break
            } else if minutes < 36 {
                return "half an hour \(adverb)"
            } else {
                biggestDifference = ("hour", 1)
            }
        case "hour":
            let hours = biggestDifference.amount
            if hours < 22 {
                break
            } else {
                biggestDifference = ("day", 1)
            }
        case "day":
            let days = biggestDifference.amount
            if days < 6 {
                break
            } else {
                biggestDifference = ("week", 1)
            }
        case "week":
            let weeks = biggestDifference.amount
            if weeks < 4 {
                break
            } else {
                biggestDifference = ("month", 1)
            }
        case "month":
            let months = biggestDifference.amount
            if months < 5 || (9...10).contains(months) {
                break
            } else if months < 9 {
                return "half a year \(adverb)"
            } else {
                biggestDifference = ("year", 1)
            }
        case "year":
            let years = trunc(biggestDifference.amount) // part before decimal
            let months = Int((biggestDifference.amount - years) * 10 * 1.2)
            
            biggestDifference.amount = years
            
            if months < 5 {
                break
            } else if months < 10 {
                // x-and-a-half years
                if years == 1 {
                    biggestDifference.component = "year and a half"
                } else if years < 6 {
                    biggestDifference.component = "and a half year"
                } else {
                    // But no half years for this long ago
                    break
                }
            } else {
                // Round up
                biggestDifference.amount += 1
            }
        default:
            fatalError("Wrong unit of time reached!")
        }
        
        // Output
        let component = biggestDifference.component
        let amount = Int(biggestDifference.amount)
        // Grammar
        let phrase = amount.of(component)
        
        return "\(phrase) \(adverb)"
    }
    
    func readable(style: ReadableStyle = .normal, fuzzy: Bool = false) -> String {
        let currentTime = Date()
        
        let formatter = DateFormatter()
        // Local time
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        // Short format
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        
        return currentTime.compare(from: self, formatter: formatter, style: style, fuzzy: fuzzy)
    }
}

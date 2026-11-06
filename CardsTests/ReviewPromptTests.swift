@testable import Cards
import Foundation
import Testing

/// When the app asks for an App Store rating (PLAT-8).
struct ReviewPromptTests {
    private static func calendar(_ timeZone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone) ?? .gmt
        return calendar
    }

    private static let london = calendar("Europe/London")

    /// A moment in November 2026, given as a UTC day and time, which in London
    /// in November is the same.
    private static func date(day: Int, hour: Int, minute: Int = 0) -> Date {
        let components = DateComponents(year: 2_026, month: 11, day: day, hour: hour, minute: minute)
        return Self.calendar("UTC").date(from: components) ?? .distantPast
    }

    /// The prompt after a card is shown at each of `dates` in `version`.
    private static func shown(
        _ dates: [Date],
        version: String = "1.4",
        calendar: Calendar = london,
        from start: ReviewPrompt = ReviewPrompt()
    ) -> ReviewPrompt {
        dates.reduce(into: start) { prompt, date in
            prompt.recordCardShown(at: date, version: version, calendar: calendar)
        }
    }

    @Test func isNotDueBeforeAnyCardIsShown() {
        #expect(!ReviewPrompt().isDue(in: "1.4"))
    }

    @Test(arguments: [1, 2])
    func isNotDueBeforeTheThirdDay(days: Int) {
        let prompt = Self.shown((1...days).map { Self.date(day: $0, hour: 12) })
        #expect(prompt.daysShown == days)
        #expect(!prompt.isDue(in: "1.4"))
    }

    @Test(arguments: [3, 4, 10])
    func isDueFromTheThirdDay(days: Int) {
        let prompt = Self.shown((1...days).map { Self.date(day: $0, hour: 12) })
        #expect(prompt.isDue(in: "1.4"))
    }

    @Test func manyCardsOnTheFirstDayCountOnce() {
        // However much the app is used on the day it is installed, it never asks that day.
        let prompt = Self.shown((0..<20).map { Self.date(day: 6, hour: 8, minute: $0) })
        #expect(prompt.daysShown == 1)
        #expect(!prompt.isDue(in: "1.4"))
    }

    @Test func asksOncePerVersion() {
        var prompt = Self.shown([Self.date(day: 1, hour: 9), Self.date(day: 2, hour: 9), Self.date(day: 3, hour: 9)])
        prompt.recordAsked(in: "1.4")
        #expect(!prompt.isDue(in: "1.4"))

        let later = Self.shown((4...30).map { Self.date(day: $0, hour: 9) }, from: prompt)
        #expect(later.asked)
        #expect(!later.isDue(in: "1.4"))
    }

    @Test func aNewVersionStartsTheCountAgain() {
        var prompt = Self.shown([Self.date(day: 1, hour: 9), Self.date(day: 2, hour: 9), Self.date(day: 3, hour: 9)])
        prompt.recordAsked(in: "1.4")

        let updated = Self.shown([Self.date(day: 4, hour: 9)], version: "1.5", from: prompt)
        #expect(updated.version == "1.5")
        #expect(updated.daysShown == 1)
        #expect(!updated.asked)
        #expect(!updated.isDue(in: "1.5"))

        let settled = Self.shown([Self.date(day: 5, hour: 9), Self.date(day: 6, hour: 9)], version: "1.5", from: updated)
        #expect(settled.isDue(in: "1.5"))
    }

    @Test func daysInAnOldVersionDoNotCarryOver() {
        // Two days in 1.4 and one in 1.5 are not three days in either.
        let prompt = Self.shown([Self.date(day: 1, hour: 9), Self.date(day: 2, hour: 9)])
        let updated = Self.shown([Self.date(day: 3, hour: 9)], version: "1.5", from: prompt)
        #expect(updated.daysShown == 1)
        #expect(!updated.isDue(in: "1.5"))
    }

    @Test func isNotDueForAnotherVersionThanTheOneCounted() {
        let prompt = Self.shown([Self.date(day: 1, hour: 9), Self.date(day: 2, hour: 9), Self.date(day: 3, hour: 9)])
        #expect(!prompt.isDue(in: "1.5"))
    }

    @Test func askingInANewVersionBeforeAnyCardStartsThatVersion() {
        var prompt = Self.shown([Self.date(day: 1, hour: 9), Self.date(day: 2, hour: 9), Self.date(day: 3, hour: 9)])
        prompt.recordAsked(in: "1.5")
        #expect(prompt == ReviewPrompt(version: "1.5", asked: true))
    }

    @Test func minutesEitherSideOfMidnightAreTwoDays() {
        let prompt = Self.shown([Self.date(day: 6, hour: 23, minute: 50), Self.date(day: 7, hour: 0, minute: 10)])
        #expect(prompt.daysShown == 2)
    }

    @Test func morningAndEveningOfOneDayAreOneDay() {
        let prompt = Self.shown([Self.date(day: 6, hour: 0, minute: 5), Self.date(day: 6, hour: 23, minute: 55)])
        #expect(prompt.daysShown == 1)
    }

    @Test func daysFollowTheCalendarsTimeZone() {
        // 10:00 and 16:00 UTC are one day in London and two in Tokyo, where 16:00 UTC is 01:00 the next day.
        let dates = [Self.date(day: 6, hour: 10), Self.date(day: 6, hour: 16)]
        #expect(Self.shown(dates, calendar: Self.london).daysShown == 1)
        #expect(Self.shown(dates, calendar: Self.calendar("Asia/Tokyo")).daysShown == 2)
    }

    @Test func aClockSetBackDoesNotAddADay() {
        let prompt = Self.shown([Self.date(day: 6, hour: 9), Self.date(day: 4, hour: 9)])
        #expect(prompt.daysShown == 1)
        #expect(prompt.lastShown == Self.date(day: 6, hour: 9))
    }

    @Test func keepsItsStateThroughTheStoredValue() throws {
        var prompt = Self.shown([Self.date(day: 1, hour: 9), Self.date(day: 2, hour: 9)])
        prompt.recordAsked(in: "1.4")
        let stored = try #require(ReviewPrompt(rawValue: prompt.rawValue))
        #expect(stored == prompt)
        #expect(ReviewPrompt(rawValue: ReviewPrompt().rawValue) == ReviewPrompt())
    }

    @Test func theStoredValueIsTheSameEveryTime() {
        // JSON keys come out in any order unless sorted, which made equal states store differently.
        let prompt = Self.shown([Self.date(day: 1, hour: 9)])
        #expect(Set((0..<50).map { _ in prompt.rawValue }).count == 1)
    }

    @Test func equalityComparesTheStateNotTheStoredText() {
        let prompt = Self.shown([Self.date(day: 1, hour: 9)])
        #expect(prompt == ReviewPrompt(version: "1.4", daysShown: 1, lastShown: Self.date(day: 1, hour: 9)))
        #expect(prompt != ReviewPrompt(version: "1.4", daysShown: 2, lastShown: Self.date(day: 1, hour: 9)))
    }

    @Test(arguments: ["", "not json", "{\"version\":\"1.4\"}"])
    func anUnreadableStoredValueStartsAgain(rawValue: String) {
        #expect(ReviewPrompt(rawValue: rawValue) == nil)
    }
}

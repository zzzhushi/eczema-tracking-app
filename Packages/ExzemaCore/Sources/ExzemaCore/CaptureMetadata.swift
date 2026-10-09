import Foundation

/// The instant a photo was taken and the time zone it was taken in.
public struct CaptureMoment: Equatable, Sendable {
    public let instant: Date
    public let timeZone: TimeZone

    public init(instant: Date, timeZone: TimeZone) {
        self.instant = instant
        self.timeZone = timeZone
    }
}

/// What the camera recorded about a capture, as read from its EXIF metadata.
public struct CaptureMetadata: Equatable, Sendable {
    /// The lens model, which names the camera used, such as "iPhone 15 Pro front camera 2.69mm f/1.9".
    public let lensModel: String?
    /// The shutter time as written by the camera, `yyyy:MM:dd HH:mm:ss` in the zone it was taken in.
    public let dateTimeOriginal: String?
    /// The shutter time's offset from UTC as `±HH:MM`.
    public let offsetTimeOriginal: String?

    public init(lensModel: String?, dateTimeOriginal: String?, offsetTimeOriginal: String?) {
        self.lensModel = lensModel
        self.dateTimeOriginal = dateTimeOriginal
        self.offsetTimeOriginal = offsetTimeOriginal
    }

    /// Return the shutter instant and the zone it was taken in, or nil when the camera recorded no readable time.
    ///
    /// The recorded offset places the time and gives the zone; `fallbackZone` is used when there is no readable
    /// offset, and is kept as the zone when it has the same offset at that instant. The system camera's Use Photo
    /// step can come well after the shutter, so the shutter time is preferred to the time of saving.
    public func shutterMoment(fallbackZone: TimeZone) -> CaptureMoment? {
        guard let text = dateTimeOriginal, let parts = Self.parts(of: text) else { return nil }
        let offsetZone = Self.zone(forOffset: offsetTimeOriginal)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = offsetZone ?? fallbackZone
        let components = DateComponents(
            year: parts[0], month: parts[1], day: parts[2], hour: parts[3], minute: parts[4], second: parts[5]
        )
        guard let instant = calendar.date(from: components) else { return nil }
        let back = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: instant)
        guard [back.year, back.month, back.day, back.hour, back.minute, back.second] == parts else { return nil }
        guard let offsetZone else { return CaptureMoment(instant: instant, timeZone: fallbackZone) }
        let agrees = fallbackZone.secondsFromGMT(for: instant) == offsetZone.secondsFromGMT(for: instant)
        return CaptureMoment(instant: instant, timeZone: agrees ? fallbackZone : offsetZone)
    }

    private static func parts(of text: String) -> [Int]? {
        let halves = text.split(separator: " ", omittingEmptySubsequences: false)
        guard halves.count == 2,
              let date = integers(halves[0], separator: ":", count: 3),
              let time = integers(halves[1], separator: ":", count: 3)
        else { return nil }
        return date + time
    }

    private static func zone(forOffset offset: String?) -> TimeZone? {
        guard let offset, let sign = offset.first, sign == "+" || sign == "-",
              let fields = integers(offset.dropFirst(), separator: ":", count: 2),
              (0...14).contains(fields[0]), (0..<60).contains(fields[1])
        else { return nil }
        let seconds = (fields[0] * 3600 + fields[1] * 60) * (sign == "-" ? -1 : 1)
        return TimeZone(secondsFromGMT: seconds)
    }

    /// Split `text` into exactly `count` fields of ASCII digits; any other shape gives nil rather than dropping fields.
    private static func integers(_ text: Substring, separator: Character, count: Int) -> [Int]? {
        let fields = text.split(separator: separator, omittingEmptySubsequences: false)
        guard fields.count == count else { return nil }
        var numbers: [Int] = []
        for field in fields {
            guard !field.isEmpty, field.allSatisfy({ $0.isASCII && $0.isNumber }), let number = Int(field) else { return nil }
            numbers.append(number)
        }
        return numbers
    }
}

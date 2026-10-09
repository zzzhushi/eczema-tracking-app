import Foundation

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

    /// Return the instant of the shutter, or nil when the camera recorded no readable time.
    ///
    /// The recorded offset places the time; without a readable offset, `fallbackZone` does. The system camera's
    /// Use Photo step can come well after the shutter, so the shutter time is preferred to the time of saving.
    public func shutterTime(fallbackZone: TimeZone) -> Date? {
        guard let text = dateTimeOriginal, let parts = Self.parts(of: text) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.zone(forOffset: offsetTimeOriginal) ?? fallbackZone
        let components = DateComponents(
            year: parts[0], month: parts[1], day: parts[2], hour: parts[3], minute: parts[4], second: parts[5]
        )
        guard let date = calendar.date(from: components) else { return nil }
        let back = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let roundTrip = [back.year, back.month, back.day, back.hour, back.minute, back.second]
        return roundTrip == parts ? date : nil
    }

    private static func parts(of text: String) -> [Int]? {
        let halves = text.split(separator: " ", omittingEmptySubsequences: false)
        guard halves.count == 2 else { return nil }
        let date = halves[0].split(separator: ":", omittingEmptySubsequences: false).compactMap { Int($0) }
        let time = halves[1].split(separator: ":", omittingEmptySubsequences: false).compactMap { Int($0) }
        guard date.count == 3, time.count == 3 else { return nil }
        return date + time
    }

    private static func zone(forOffset offset: String?) -> TimeZone? {
        guard let offset, let sign = offset.first, sign == "+" || sign == "-" else { return nil }
        let fields = offset.dropFirst().split(separator: ":", omittingEmptySubsequences: false).compactMap { Int($0) }
        guard fields.count == 2, (0...14).contains(fields[0]), (0..<60).contains(fields[1]) else { return nil }
        let seconds = (fields[0] * 3600 + fields[1] * 60) * (sign == "-" ? -1 : 1)
        return TimeZone(secondsFromGMT: seconds)
    }
}

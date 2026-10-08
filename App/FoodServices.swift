import ExzemaCore
import Observation

/// What the food section needs from the app, supplied through the environment so the view takes only a day.
///
/// Either member is nil when it failed to load; the section then says food logging is unavailable.
@Observable
final class FoodServices {
    let store: DayStore?
    let matching: FoodMatching?
    /// Holds the unsaved text and open edits, kept per date so they survive the screen changing day.
    let session: DaySession

    init(store: DayStore?, matching: FoodMatching?, session: DaySession) {
        self.store = store
        self.matching = matching
        self.session = session
    }
}

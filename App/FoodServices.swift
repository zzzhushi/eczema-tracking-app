import ExzemaCore
import Observation

/// What the food section needs from the app, supplied through the environment so the view takes only a day.
///
/// Either member is nil when it failed to load; the section then says food logging is unavailable.
@Observable
final class FoodServices {
    let store: DayStore?
    let matching: FoodMatching?
    /// Unsaved text and open edits, kept per date so they survive the screen changing day.
    let drafts: FoodDrafts

    init(store: DayStore?, matching: FoodMatching?, drafts: FoodDrafts) {
        self.store = store
        self.matching = matching
        self.drafts = drafts
    }
}

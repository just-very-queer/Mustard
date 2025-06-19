import SwiftUI

// MARK: - Placeholder Views (Ensure these exist)
struct SearchFiltersView: View {
    @Binding var filters: SearchViewModel.SearchFilters
    var onApply: () -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        Form {
             Section("General") {
                 Toggle("Include Full Profile Data (Resolve)", isOn: Binding(
                     get: { filters.resolve ?? true },
                     set: { filters.resolve = $0 }
                 ))
                 Toggle("Exclude Unreviewed Content", isOn: Binding(
                      get: { filters.excludeUnreviewed ?? false },
                      set: { filters.excludeUnreviewed = $0 }
                 ))
             }
             Section("Pagination / ID") {
                  TextField("Max Status ID", text: Binding(
                      get: { filters.maxId ?? "" },
                      set: { filters.maxId = $0.isEmpty ? nil : $0 }
                  ))
                  .keyboardType(.numberPad)

                 TextField("Min Status ID", text: Binding(
                      get: { filters.minId ?? "" },
                      set: { filters.minId = $0.isEmpty ? nil : $0 }
                  ))
                  .keyboardType(.numberPad)

                 Stepper("Limit: \(filters.limit ?? 20)", value: Binding(
                     get: { filters.limit ?? 20 },
                     set: { filters.limit = $0 }
                 ), in: 5...40, step: 5)
             }
         }
    }
}

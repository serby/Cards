import Foundation

extension DistanceUnits {
    /// The choice as Settings lists it. Automatic says what it means where
    /// `locale` applies: "Automatic (Kilometres)" or "Automatic (Miles)".
    func title(for locale: Locale) -> String {
        switch self {
        case .automatic:
            String(
                localized: "Automatic (\(resolved(for: locale).title(for: locale)))",
                comment: """
                    A choice in Settings > Distances: the units that follow the iPhone's measurement system. \
                    The argument is those units, Kilometres or Miles.
                    """
            )
        case .kilometres:
            String(localized: "Kilometres", comment: "A choice in Settings > Distances: show distances in metres and kilometres.")
        case .miles:
            String(localized: "Miles", comment: "A choice in Settings > Distances: show distances in yards and miles.")
        }
    }
}

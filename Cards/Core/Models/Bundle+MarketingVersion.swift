import Foundation

extension Bundle {
    /// The version people see, such as "1.4": `CFBundleShortVersionString`,
    /// which the project sets from `MARKETING_VERSION`.
    var marketingVersion: String? {
        infoDictionary?["CFBundleShortVersionString"] as? String
    }
}

/// Release version and build number.
///
/// `version` is the semantic version — bump it by hand for a release.
/// `build` is incremented automatically by `scripts/deploy.sh` on each deploy.
enum BuildInfo {
    static let version = "0.1.3"
    static let build = 11
}

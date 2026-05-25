import Foundation

struct AppUpdateResult: Equatable {
    var tagName: String
    var fileURL: URL
}

struct AppReleaseInfo: Equatable {
    var tagName: String
    fileprivate var dmgAsset: GitHubReleaseAsset?
}

enum AppUpdateError: LocalizedError {
    case invalidReleaseURL
    case missingDMGAsset
    case invalidDownloadDirectory
    case releaseLookupFailed(String)
    case invalidReleaseResponse(String)

    var errorDescription: String? {
        switch self {
        case .invalidReleaseURL:
            "Invalid release URL."
        case .missingDMGAsset:
            "No DMG asset found in the latest release."
        case .invalidDownloadDirectory:
            "Downloads folder is unavailable."
        case let .releaseLookupFailed(message):
            "Could not check latest version: \(message)"
        case let .invalidReleaseResponse(message):
            "Could not read latest version data: \(message)"
        }
    }
}

struct AppUpdater {
    private let latestReleaseURL = URL(string: "https://api.github.com/repos/bairizuomeng00-a11y/ModelRoom/releases/latest")

    func latestRelease() async throws -> AppReleaseInfo {
        guard let latestReleaseURL else {
            throw AppUpdateError.invalidReleaseURL
        }

        var request = URLRequest(url: latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("ModelRoom", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let (releaseData, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            let message = GitHubAPIMessage.message(from: releaseData)
                ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw AppUpdateError.releaseLookupFailed("HTTP \(http.statusCode) \(message)")
        }

        let release: GitHubRelease
        do {
            release = try JSONDecoder().decode(GitHubRelease.self, from: releaseData)
        } catch {
            let preview = String(data: releaseData.prefix(220), encoding: .utf8)?
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw AppUpdateError.invalidReleaseResponse(preview ?? error.localizedDescription)
        }

        return AppReleaseInfo(
            tagName: release.tag_name,
            dmgAsset: release.assets.first { $0.name.lowercased().hasSuffix(".dmg") }
        )
    }

    func isRelease(_ release: AppReleaseInfo, newerThan currentVersion: String) -> Bool {
        let remote = versionParts(from: release.tagName)
        let current = versionParts(from: currentVersion)

        if !remote.isEmpty, !current.isEmpty {
            for index in 0..<max(remote.count, current.count) {
                let lhs = index < remote.count ? remote[index] : 0
                let rhs = index < current.count ? current[index] : 0
                if lhs != rhs {
                    return lhs > rhs
                }
            }
            return false
        }

        return normalizedVersion(release.tagName) != normalizedVersion(currentVersion)
    }

    func downloadDMG(from release: AppReleaseInfo) async throws -> AppUpdateResult {
        guard let asset = release.dmgAsset,
              let assetURL = URL(string: asset.browser_download_url) else {
            throw AppUpdateError.missingDMGAsset
        }

        let (temporaryURL, _) = try await URLSession.shared.download(from: assetURL)
        let destination = try destinationURL(for: asset.name, tagName: release.tagName)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return AppUpdateResult(tagName: release.tagName, fileURL: destination)
    }

    private func destinationURL(for assetName: String, tagName: String) throws -> URL {
        guard let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            throw AppUpdateError.invalidDownloadDirectory
        }

        let cleanedTag = tagName.replacingOccurrences(of: "/", with: "-")
        let baseName = assetName.replacingOccurrences(of: ".dmg", with: "", options: [.caseInsensitive])
        return downloads.appendingPathComponent("\(baseName)-\(cleanedTag).dmg")
    }

    private func versionParts(from version: String) -> [Int] {
        normalizedVersion(version)
            .split(separator: ".")
            .compactMap { Int($0) }
    }

    private func normalizedVersion(_ version: String) -> String {
        let value = version
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return value.hasPrefix("v") ? String(value.dropFirst()) : value
    }
}

private struct GitHubRelease: Decodable {
    var tag_name: String
    var assets: [GitHubReleaseAsset]
}

private struct GitHubReleaseAsset: Decodable, Equatable {
    var name: String
    var browser_download_url: String
}

private struct GitHubAPIMessage: Decodable {
    var message: String

    static func message(from data: Data) -> String? {
        try? JSONDecoder().decode(Self.self, from: data).message
    }
}

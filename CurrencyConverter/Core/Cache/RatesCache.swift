//
//  RatesCache.swift
//  CurrencyConverter
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import Foundation
import os

/// Non-throwing on purpose: a bad load is just a miss, and a failed save
/// costs a re-fetch rather than a crash.
protocol RatesCacheProtocol: Sendable {
    func load() -> RatesSnapshot?
    func save(_ snapshot: RatesSnapshot)
}

/// One JSON file in Application Support. Not Caches/, which the OS can purge
/// that under storage pressure, which would break offline support.
struct RatesCache: RatesCacheProtocol {

    private let fileURL: URL

    init(directory: URL? = nil) {
        let base = directory ?? URL.applicationSupportDirectory
        self.fileURL = base.appending(path: "rates-snapshot.json")
    }

    func load() -> RatesSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil // no file yet, normal on first launch
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let snapshot = try? decoder.decode(RatesSnapshot.self, from: data) else {
            // corrupt or truncated; next successful fetch overwrites it
            Log.app.error("snapshot file exists but did not decode, treating as miss")
            return nil
        }
        return snapshot
    }

    func save(_ snapshot: RatesSnapshot) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
            excludeFromBackup()
        } catch {
            // non-fatal; the session keeps running on in-memory data
            Log.app.error("snapshot save failed: \(error.localizedDescription)")
        }
    }

    // rates are public, re-fetchable data; no reason to back them up
    private func excludeFromBackup() {
        var url = fileURL
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        do {
            try url.setResourceValues(values)
        } catch {
            Log.app.notice("could not set backup exclusion: \(error.localizedDescription)")
        }
    }
}

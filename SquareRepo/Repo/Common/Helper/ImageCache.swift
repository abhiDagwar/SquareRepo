//
//  ImageCache.swift
//  SquareRepo
//
//  Created by Abhishek Dagwar on 22/04/26.
//

import UIKit

// MARK: - Protocol (injectable for tests)
protocol ImageCacheProtocol {
    func image(for url: URL) async -> UIImage?
}

// MARK: - Actor-isolated cache
actor ImageCache: ImageCacheProtocol {
    // MARK: Shared instance
    static let shared = ImageCache()
    
    // MARK: Storage
    /// Initial count limit to apply when the cache is first created.
    private let initialCountLimit: Int
    /// Decoded UIImages, keyed by URL string.
    private lazy var cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = initialCountLimit
        return c
    }()
    /// In-flight tasks, keyed by URL string.
    /// Prevents duplicate network requests for the same URL.
    private var inFlight: [String: Task<UIImage?, Never>] = [:]
    
    // MARK: Init
    init(countLimit: Int = 100) {
        self.initialCountLimit = countLimit
    }
    
    // MARK: ImageCacheProtocol
    func image(for url: URL) async -> UIImage? {
        let key = url.absoluteString as NSString

        // 1. Cache hit — return immediately.
        if let cached = cache.object(forKey: key) {
            return cached
        }

        // 2. Already fetching this URL — await the existing task.
        if let existing = inFlight[url.absoluteString] {
            return await existing.value
        }

        // 3. New request — create a task, store it, then await it.
        let task = Task<UIImage?, Never> {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                return UIImage(data: data)
            } catch {
                return nil
            }
        }

        inFlight[url.absoluteString] = task
        let image = await task.value
        inFlight.removeValue(forKey: url.absoluteString)

        if let image {
            cache.setObject(image, forKey: key)
        }

        return image
    }

    // MARK: Cache management
    func clearCache() {
        cache.removeAllObjects()
    }
}

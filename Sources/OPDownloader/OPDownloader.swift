// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftUI
import Combine
import MZDownloadManager

public class OPDownloader: NSObject, ObservableObject {
    
    // MARK: - Injected Properties
    
    @Published public var inProcessings: [URL : State] = [:]
    
    // MARK: - Internal Properties
    
    internal var manager: MZDownloadManager?
    
    // MARK: - Initializers
    
    public init(backgroundSessionCompletionHandler: BackgroundSessionCompletionHandler? = nil, lastPathSessionIdentifier: String? = nil) {
        super.init()
        
        let sessionIdentifier: String
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            if let lastPathSessionIdentifier = lastPathSessionIdentifier {
                sessionIdentifier = "\(bundleIdentifier).BackgroundSession-\(lastPathSessionIdentifier)"
            } else {
                sessionIdentifier = "\(bundleIdentifier).BackgroundSession"
            }
        } else {
            if let lastPathSessionIdentifier = lastPathSessionIdentifier {
                sessionIdentifier = "com.\(UUID().uuidString).BackgroundSession-\(lastPathSessionIdentifier)"
            } else {
                sessionIdentifier = "com.\(UUID().uuidString).BackgroundSession"
            }
        }
        
        self.manager = MZDownloadManager(session: sessionIdentifier, delegate: self, completion: backgroundSessionCompletionHandler)
    }
    
    // MARK: - Public Properties
    
    public let stateChanged = PassthroughSubject<ItemState, Never>()
    public var downloadingItems: [MZDownloadModel] {
        if let manager = manager {
            return manager.downloadingArray
        }
        return []
    }
}

// MARK: - Public Methods

extension OPDownloader {
    
    public func downloadFile(at url: URL, to destinationURL: URL = FileManager.default.temporaryDirectory) {
        makeHeadRequest(url: url) { result in
            switch result {
            case .success(let httpResponse):
                if let fileName = httpResponse.suggestedFilename {
                    let outputURL = destinationURL.appendingPathComponent(fileName)
                    if FileManager.default.fileExists(atPath: outputURL.path) {
                        DispatchQueue.main.async {
                            self.stateChanged.send((nil, .finished(outputURL)))
                            self.inProcessings[url] = .finished(outputURL)
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.inProcessings[url] = .idle
                        }
                        
                        self.manager?.addDownloadTask(fileName, fileURL: url.absoluteString, destinationPath: destinationURL.path)
                    }
                }
            case .failure(let error):
                #if DEBUG
                print("HEAD request failed with error: \(error)")
                #endif
                DispatchQueue.main.async {
                    self.stateChanged.send((nil, .failed(error)))
                    self.inProcessings[url] = .failed(error)
                }
            }
        }
    }
    
    public func perform(operation: Operation, on item: MZDownloadModel) {
        switch operation {
        case .download:
            break
        case .pause:
            pauseDownloadTask(item)
        case .resume:
            resumeDownloadTask(item)
        case .cancel:
            cancelDownloadTask(item)
        }
    }
    
    public func perform(operation: Operation, at url: URL) {
        if let item = downloadingItems.first(where: { $0.fileURL == url.absoluteString }) {
            perform(operation: operation, on: item)
        }
    }
    
    public func makeHeadRequest(url: URL, completion: @escaping (Result<HTTPURLResponse, Error>) -> Void) {
        // Create a URL request and set the HTTP method to HEAD
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        
        // Create a data task with the URLSession
        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                // Return the error if the request failed
                completion(.failure(error))
            } else if let httpResponse = response as? HTTPURLResponse {
                // Return the HTTP response if the request succeeded
                completion(.success(httpResponse))
            } else {
                // Handle unexpected response type
                let unexpectedResponseError = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unexpected response type"])
                completion(.failure(unexpectedResponseError))
            }
        }
        
        // Start the task
        task.resume()
    }
}

private extension OPDownloader {
    
    private func pauseDownloadTask(_ item: MZDownloadModel) {
        if let index = manager?.downloadingArray.firstIndex(where: { $0 == item }) {
            manager?.pauseDownloadTaskAtIndex(index)
            DispatchQueue.main.async {
                if let url = URL(string: item.fileURL) {
                    self.inProcessings[url] = .paused(item.progress)
                }
            }
        }
    }
    
    private func resumeDownloadTask(_ item: MZDownloadModel) {
        if let index = manager?.downloadingArray.firstIndex(where: { $0 == item }) {
            manager?.resumeDownloadTaskAtIndex(index)
        }
    }
    
    private func cancelDownloadTask(_ item: MZDownloadModel) {
        if let index = manager?.downloadingArray.firstIndex(where: { $0 == item }) {
            manager?.cancelTaskAtIndex(index)
            DispatchQueue.main.async {
                if let url = URL(string: item.fileURL) {
                    self.inProcessings[url] = .canceled
                }
            }
        }
    }
}

// MARK: - MZDownloadManagerDelegate

extension OPDownloader: MZDownloadManagerDelegate {
    
    public func downloadRequestStarted(_ downloadModel: MZDownloadModel, index: Int) {
        #if DEBUG
        print("DOWNLOAD_STARTED: \(String(describing: downloadModel.fileName))")
        #endif
        DispatchQueue.main.async {
            self.stateChanged.send((downloadModel, .started))
        }
    }
    
    public func downloadRequestDidPopulatedInterruptedTasks(_ downloadModels: [MZDownloadModel]) {
        #if DEBUG
        print("DOWNLOAD_INTERRUPTED_TASKS: \(downloadModels)")
        #endif
        DispatchQueue.main.async {
            self.stateChanged.send((downloadModels.first, .interrupted))
        }
    }
    
    public func downloadRequestDidUpdateProgress(_ downloadModel: MZDownloadModel, index: Int) {
        #if DEBUG
        print("DOWNLOADING: \(String(describing: downloadModel.fileName)) - \(String(describing: downloadModel.progress))")
        #endif
        DispatchQueue.main.async {
            if let url = URL(string: downloadModel.fileURL) {
                self.inProcessings[url] = .downloading(downloadModel.progress)
            }
        }
    }
    
    public func downloadRequestDidPaused(_ downloadModel: MZDownloadModel, index: Int) {
        #if DEBUG
        print("DOWNLOAD_PAUSED: \(String(describing: downloadModel.fileName))")
        #endif
        
        DispatchQueue.main.async {
            self.stateChanged.send((downloadModel, .paused(downloadModel.progress)))
            if let url = URL(string: downloadModel.fileURL) {
                self.inProcessings[url] = .paused(downloadModel.progress)
            }
        }
    }
    
    public func downloadRequestDidResumed(_ downloadModel: MZDownloadModel, index: Int) {
        #if DEBUG
        print("DOWNLOAD_RESUMED: \(String(describing: downloadModel.fileName))")
        #endif
        DispatchQueue.main.async {
            self.stateChanged.send((downloadModel, .resumed))
        }
    }
    
    public func downloadRequestCanceled(_ downloadModel: MZDownloadModel, index: Int) {
        #if DEBUG
        print("DOWNLOAD_CANCELED: \(String(describing: downloadModel.fileName))")
        #endif
        DispatchQueue.main.async {
            self.stateChanged.send((downloadModel, .canceled))
            if let url = URL(string: downloadModel.fileURL) {
                self.inProcessings[url] = .canceled
            }
        }
    }
    
    public func downloadRequestFinished(_ downloadModel: MZDownloadModel, index: Int) {
        if let destinationURL = URL(string: downloadModel.destinationPath), let fileURL = URL(string: downloadModel.fileURL) {
            DispatchQueue.main.async {
                let outputURL = destinationURL.appendingPathComponent(downloadModel.fileName)
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    #if DEBUG
                    print("DOWNLOAD_FINISHED: \(String(describing: outputURL.absoluteString))")
                    #endif
                    self.stateChanged.send((downloadModel, .finished(outputURL)))
                    self.inProcessings[fileURL] = .finished(outputURL)
                }
            }
        }
    }
    
    public func downloadRequestDidFailedWithError(_ error: NSError, downloadModel: MZDownloadModel, index: Int) {
        #if DEBUG
        print("DOWNLOAD_FAILED: \(String(describing: downloadModel.fileName)) - \(error.localizedDescription)")
        #endif
        DispatchQueue.main.async {
            self.stateChanged.send((downloadModel, .failed(error)))
            if let url = URL(string: downloadModel.fileURL) {
                self.inProcessings[url] = .failed(error)
            }
        }
    }
    
    public func downloadRequestDestinationDoestNotExists(_ downloadModel: MZDownloadModel, index: Int, location: URL) {
        #if DEBUG
        print("Download destination does not exist: \(String(describing: downloadModel.fileName))")
        #endif
        DispatchQueue.main.async {
            self.stateChanged.send((downloadModel, .destinationDoestNotExists(location)))
        }
    }
    
    public func downloadRequestDidMoved(_ location: URL, downloadModel: MZDownloadModel, index: Int) {
        #if DEBUG
        print("Download moved: \(String(describing: downloadModel.fileName))")
        #endif
        DispatchQueue.main.async {
            self.stateChanged.send((downloadModel, .didMoved))
        }
    }
    
    public func downloadRequestDidDuplicateDownload(_ downloadModel: MZDownloadModel, index: Int) {
        #if DEBUG
        print("Download duplicate: \(String(describing: downloadModel.fileName))")
        #endif
        DispatchQueue.main.async {
            self.stateChanged.send((downloadModel, .duplicateDownload))
        }
    }
    
    public func downloadRequestDidExceedQuotaRestriction(_ downloadModel: MZDownloadModel, index: Int) {
        #if DEBUG
        print("Download exceed quota: \(String(describing: downloadModel.fileName))")
        #endif
        DispatchQueue.main.async {
            self.stateChanged.send((downloadModel, .exceedQuotaRestriction))
        }
    }
    
    public func downloadRequestAuthenticationRequired(_ downloadModel: MZDownloadModel, index: Int) {
        #if DEBUG
        print("Download authentication required: \(String(describing: downloadModel.fileName))")
        #endif
        DispatchQueue.main.async {
            self.stateChanged.send((downloadModel, .authenticationRequired))
        }
    }
    
    public func downloadRequestDidReceiveData(_ downloadModel: MZDownloadModel, index: Int) {
        #if DEBUG
        print("Download received data: \(String(describing: downloadModel.fileName))")
        #endif
        DispatchQueue.main.async {
            self.stateChanged.send((downloadModel, .didReceiveData))
        }
    }
}

// MARK: - DownloadViewModel.BackgroundSessionCompletionHandler

extension OPDownloader {
    public typealias BackgroundSessionCompletionHandler = () -> Void
    public typealias ItemState = (Item?, State)
    public typealias Item = MZDownloadModel
}

// MARK: - DownloadViewModel.Operation

extension OPDownloader {
    
    public enum Operation: String, Identifiable, Hashable, CaseIterable {
        case download = "Download"
        case pause = "Pause"
        case resume = "Resume"
        case cancel = "Cancel"
        
        public var id: String {
            rawValue
        }
    }
}

// MARK: - DownloadViewModel.State

extension OPDownloader {
    
    public enum State: Identifiable, Hashable, Equatable {
        case idle
        case downloading(Float)
        case paused(Float)
        case resumed
        case canceled
        case started
        case finished(URL)
        case failed(Error)
        case interrupted
        case destinationDoestNotExists(URL)
        case didMoved
        case duplicateDownload
        case exceedQuotaRestriction
        case authenticationRequired
        case didReceiveData
        
        public var id: String {
            switch self {
            case .idle:
                return "idle"
            case .downloading(_):
                return "downloading"
            case .paused(_):
                return "pause"
            case .canceled:
                return "canceled"
            case .finished:
                return "finished"
            case .failed:
                return "failed"
            case .interrupted:
                return "interrupted"
            case .destinationDoestNotExists(_):
                return "destinationDoestNotExists"
            case .didMoved:
                return "didMoved"
            case .duplicateDownload:
                return "duplicateDownload"
            case .exceedQuotaRestriction:
                return "exceedQuotaRestriction"
            case .authenticationRequired:
                return "authenticationRequired"
            case .didReceiveData:
                return "didReceiveData"
            case .started:
                return "started"
            case .resumed:
                return "resumed"
            }
        }
        
        public static func == (lhs: OPDownloader.State, rhs: OPDownloader.State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle):
                return true
            case (.downloading, .downloading):
                return true
            case (.paused, .paused):
                return true
            case (.canceled, .canceled):
                return true
            case (.finished, .finished):
                return true
            case (.failed, .failed):
                return true
            default:
                return true
            }
        }
        
        // Conform to Hashable
        
        public func hash(into hasher: inout Hasher) {
            switch self {
            case .idle:
                hasher.combine("idle")
            case .downloading:
                hasher.combine("downloading")
            case .paused:
                hasher.combine("paused")
            case .canceled:
                hasher.combine("canceled")
            case .finished:
                hasher.combine("finished")
            case .failed:
                hasher.combine("failed")
            case .interrupted:
                hasher.combine("interrupted")
            case .destinationDoestNotExists:
                hasher.combine("destinationDoestNotExists")
            case .didMoved:
                hasher.combine("didMoved")
            case .duplicateDownload:
                hasher.combine("duplicateDownload")
            case .exceedQuotaRestriction:
                hasher.combine("exceedQuotaRestriction")
            case .authenticationRequired:
                hasher.combine("authenticationRequired")
            case .didReceiveData:
                hasher.combine("didReceiveData")
            case .started:
                hasher.combine("started")
            case .resumed:
                hasher.combine("resumed")
            }
        }
    }
}

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
    
    public init(backgroundSessionCompletionHandler: BackgroundSessionCompletionHandler? = nil) {
        super.init()
        
        let sessionIdentifier: String
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            sessionIdentifier = "\(bundleIdentifier).BackgroundSession"
        } else {
            sessionIdentifier = "com.\(UUID().uuidString).BackgroundSession"
        }
        
        self.manager = MZDownloadManager(session: sessionIdentifier, delegate: self, completion: backgroundSessionCompletionHandler)
    }
    
    // MARK: - Public Properties
    
    public let downloadStarted = PassthroughSubject<MZDownloadModel, Never>()
    public let downloadInterrupted = PassthroughSubject<[MZDownloadModel], Never>()
    public let downloadPaused = PassthroughSubject<MZDownloadModel, Never>()
    public let downloadResumed = PassthroughSubject<MZDownloadModel, Never>()
    public let downloadCanceled = PassthroughSubject<MZDownloadModel, Never>()
    public let downloadFinished = PassthroughSubject<MZDownloadModel, Never>()
    public let downloadFailed = PassthroughSubject<(MZDownloadModel, Error), Never>()
    public let destinationNotExist = PassthroughSubject<(MZDownloadModel, URL), Never>()
    public let downloadMoved = PassthroughSubject<(MZDownloadModel, URL), Never>()
    public let duplicateDownload = PassthroughSubject<MZDownloadModel, Never>()
    public let quotaExceeded = PassthroughSubject<MZDownloadModel, Never>()
    public let authenticationRequired = PassthroughSubject<MZDownloadModel, Never>()
    public let dataReceived = PassthroughSubject<MZDownloadModel, Never>()
    public let headRequestFailed = PassthroughSubject<Error, Never>()
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
        inProcessings[url] = .idle
        makeHeadRequest(url: url) { result in
            switch result {
            case .success(let httpResponse):
                if let fileName = httpResponse.suggestedFilename {
                    self.manager?.addDownloadTask(fileName,
                                                  fileURL: url.absoluteString,
                                                  destinationPath: destinationURL.path)
                }
            case .failure(let error):
                #if DEBUG
                print("HEAD request failed with error: \(error)")
                #endif
                self.headRequestFailed.send(error)
                self.inProcessings[url] = .failed(error)
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
            
            if let url = URL(string: item.fileURL) {
                inProcessings[url] = .paused(item.progress)
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
            
            if let url = URL(string: item.fileURL) {
                inProcessings[url] = .canceled
            }
        }
    }
}

// MARK: - MZDownloadManagerDelegate

extension OPDownloader: MZDownloadManagerDelegate {
    
    public func downloadRequestStarted(_ downloadModel: MZDownloadModel, index: Int) {
        #if DEBUG
        print("Download started: \(String(describing: downloadModel.fileName))")
        #endif
        downloadStarted.send(downloadModel)
    }
    
    public func downloadRequestDidPopulatedInterruptedTasks(_ downloadModels: [MZDownloadModel]) {
        #if DEBUG
        print("Download interrupted tasks: \(downloadModels)")
        #endif
        downloadInterrupted.send(downloadModels)
    }
    
    public func downloadRequestDidUpdateProgress(_ downloadModel: MZDownloadModel, index: Int) {
        if let url = URL(string: downloadModel.fileURL) {
            inProcessings[url] = .downloading(downloadModel.progress)
        }
    }
    
    public func downloadRequestDidPaused(_ downloadModel: MZDownloadModel, index: Int) {
        #if DEBUG
        print("Download paused: \(String(describing: downloadModel.fileName))")
        #endif
        downloadPaused.send(downloadModel)
        
        if let url = URL(string: downloadModel.fileURL) {
            inProcessings[url] = .paused(downloadModel.progress)
        }
    }
    
    public func downloadRequestDidResumed(_ downloadModel: MZDownloadModel, index: Int) {
        #if DEBUG
        print("Download resumed: \(String(describing: downloadModel.fileName))")
        #endif
        downloadResumed.send(downloadModel)
    }
    
    public func downloadRequestCanceled(_ downloadModel: MZDownloadModel, index: Int) {
        #if DEBUG
        print("Download canceled: \(String(describing: downloadModel.fileName))")
        #endif
        downloadCanceled.send(downloadModel)
        
        if let url = URL(string: downloadModel.fileURL) {
            inProcessings[url] = .canceled
        }
    }
    
    public func downloadRequestFinished(_ downloadModel: MZDownloadModel, index: Int) {
        #if DEBUG
        print("Download finished: \(String(describing: downloadModel.fileName))")
        #endif
        downloadFinished.send(downloadModel)
        
        if let url = URL(string: downloadModel.destinationPath) {
            inProcessings[url] = .finished(url)
        }
    }
    
    public func downloadRequestDidFailedWithError(_ error: NSError, downloadModel: MZDownloadModel, index: Int) {
        #if DEBUG
        print("Download failed: \(String(describing: downloadModel.fileName)) - \(error.localizedDescription)")
        #endif
        downloadFailed.send((downloadModel, error))
        
        if let url = URL(string: downloadModel.fileURL) {
            inProcessings[url] = .failed(error)
        }
    }
    
    public func downloadRequestDestinationDoestNotExists(_ downloadModel: MZDownloadModel, index: Int, location: URL) {
        #if DEBUG
        print("Download destination does not exist: \(String(describing: downloadModel.fileName))")
        #endif
        destinationNotExist.send((downloadModel, location))
    }
    
    public func downloadRequestDidMoved(_ location: URL, downloadModel: MZDownloadModel, index: Int) {
        #if DEBUG
        print("Download moved: \(String(describing: downloadModel.fileName))")
        #endif
        downloadMoved.send((downloadModel, location))
    }
    
    public func downloadRequestDidDuplicateDownload(_ downloadModel: MZDownloadModel, index: Int) {
        #if DEBUG
        print("Download duplicate: \(String(describing: downloadModel.fileName))")
        #endif
        duplicateDownload.send(downloadModel)
    }
    
    public func downloadRequestDidExceedQuotaRestriction(_ downloadModel: MZDownloadModel, index: Int) {
        #if DEBUG
        print("Download exceed quota: \(String(describing: downloadModel.fileName))")
        #endif
        quotaExceeded.send(downloadModel)
    }
    
    public func downloadRequestAuthenticationRequired(_ downloadModel: MZDownloadModel, index: Int) {
        #if DEBUG
        print("Download authentication required: \(String(describing: downloadModel.fileName))")
        #endif
        authenticationRequired.send(downloadModel)
    }
    
    public func downloadRequestDidReceiveData(_ downloadModel: MZDownloadModel, index: Int) {
        #if DEBUG
        print("Download received data: \(String(describing: downloadModel.fileName))")
        #endif
        dataReceived.send(downloadModel)
    }
}

// MARK: - DownloadViewModel.BackgroundSessionCompletionHandler

extension OPDownloader {
    public typealias BackgroundSessionCompletionHandler = () -> Void
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
        case canceled
        case finished(URL)
        case failed(Error)
    
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
                return false
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
            }
        }
    }
}

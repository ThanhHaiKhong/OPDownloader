//
//  File.swift
//  
//
//  Created by Thanh Hai Khong on 24/6/24.
//

import SwiftUI
import OPDownloader
import MZDownloadManager

public struct DownloadingView: View {
    
    @StateObject private var downloader: OPDownloader
    
    public init(downloader: OPDownloader) {
        self._downloader = StateObject(wrappedValue: downloader)
    }
    
    public var body: some View {
        NavigationView {
            VStack {
                if downloader.downloadingItems.isEmpty {
                    BlankView(title: "No Downloading Items",
                              imageName: "arrow.down.doc.fill",
                              description: "All downloaded files will be added to Downloads Folder",
                              foregroundColor: .blue)
                } else {
                    List {
                        ForEach(downloader.downloadingItems, id: \.fileURL) { item in
                            if let url = URL(string: item.fileURL) {
                                DownloadItemView(url: url, 
                                                 title: item.fileName,
                                                 description: item.fileURL,
                                                 downloader: downloader)
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            downloader.perform(operation: .cancel, on: item)
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.headline)
                                        }
                                    }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Downloadings")
        }
    }
}

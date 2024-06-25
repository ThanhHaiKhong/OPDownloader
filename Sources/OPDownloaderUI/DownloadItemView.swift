//
//  DownloadItemView.swift
//
//
//  Created by Thanh Hai Khong on 24/6/24.
//

import SwiftUI
import OPDownloader

public struct DownloadItemView: View {
    
    @StateObject private var downloader: OPDownloader
    
    private let url: URL
    private let title: String
    private let description: String?
    
    public init(url: URL, 
                title: String,
                description: String? = nil, downloader: OPDownloader) {
        self.url = url
        self.title = title
        self.description = description
        self._downloader = StateObject(wrappedValue: downloader)
    }
    
    public var body: some View {
        HStack {
            Image(systemName: "doc.richtext")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.primary)
                
                if let description = description {
                    Text(description)
                        .font(.footnote)
                        .fontWeight(.regular)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            CircularActivityIndicator(downloader: downloader, url: url)
        }
    }
}

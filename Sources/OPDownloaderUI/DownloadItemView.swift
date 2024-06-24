//
//  DownloadItemView.swift
//
//
//  Created by Thanh Hai Khong on 24/6/24.
//

import SwiftUI

public struct DownloadItemView: View {
    
    private let url: URL
    private let title: String
    private let description: String?
    
    public init(url: URL, 
                title: String,
                description: String? = nil) {
        self.url = url
        self.title = title
        self.description = description
    }
    
    public var body: some View {
        HStack {
            Image(systemName: "doc.richtext")
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .padding(5)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5))
            
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
            
            CircularActivityIndicator(url: url)
        }
    }
}

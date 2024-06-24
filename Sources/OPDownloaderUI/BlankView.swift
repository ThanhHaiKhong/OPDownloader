//
//  File.swift
//  
//
//  Created by Thanh Hai Khong on 24/6/24.
//

import SwiftUI

public struct BlankView: View {
    
    let title: String
    let imageName: String
    let description: String?
    let foregroundColor: Color
    
    public init(title: String, 
                imageName: String,
                description: String?,
                foregroundColor: Color) {
        self.title = title
        self.imageName = imageName
        self.description = description
        self.foregroundColor = foregroundColor
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundStyle(foregroundColor)
            
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            
            if let description = description {
                Text(description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
    }
}

extension BlankView {
    
    public init(title: String,
                imageName: String,
                description: String) {
        self.init(title: title, 
                  imageName: imageName,
                  description: description,
                  foregroundColor: .accentColor)
    }
    
    public init(title: String,
                imageName: String) {
        self.init(title: title,
                  imageName: imageName,
                  description: nil,
                  foregroundColor: .accentColor)
    }
}

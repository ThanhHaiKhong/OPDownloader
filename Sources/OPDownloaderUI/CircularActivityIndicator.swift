//
//  CircularActivityIndicator.swift
//
//
//  Created by Thanh Hai Khong on 24/6/24.
//

import SwiftUI
import OPDownloader

public struct CircularActivityIndicator: View {
    
    @StateObject private var downloader: OPDownloader
    @State private var isLoading: Bool = false
    
    private let lineWidth: CGFloat = 3
    private let pathColor: Color = .gray.opacity(0.5)
    private let lineColor: Color = .accentColor
    private let width: CGFloat = 28
    
    private let url: URL
    
    public init(downloader: OPDownloader, url: URL) {
        self._downloader = StateObject(wrappedValue: downloader)
        self.url = url
    }
    
    public var body: some View {
        if let state = downloader.inProcessings[url] {
            ZStack {
                switch state {
                case .idle:
                    loadingView()
                case .downloading(let progress):
                    downloadingView(progress: Double(progress))
                case .paused(let progress):
                    pausedView(at: Double(progress))
                case .canceled:
                    EmptyView()
                case .finished(_):
                    downloadedView()
                case .failed(_):
                    failedView()
                }
            }
            .animation(.easeInOut, value: state)
        } else {
            Button {
                downloader.downloadFile(at: url)
            } label: {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.headline)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 16)
                    .background(.regularMaterial, in: Capsule())
            }
        }
    }
}

// MARK: - View Builders

extension CircularActivityIndicator {
    
    @ViewBuilder
    private func loadingView() -> some View {
        ZStack {
            Circle()
                .stroke(pathColor, lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(lineColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .rotationEffect(Angle(degrees: isLoading ? 360 : 0))
                .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: isLoading)
                .onAppear { isLoading.toggle() }
        }
        .frame(width: width, height: width)
    }
    
    @ViewBuilder
    private func downloadingView(progress: Double) -> some View {
        ZStack {
            Circle()
                .stroke(pathColor, lineWidth: lineWidth)
            
            Button {
                withAnimation {
                    downloader.perform(operation: .pause, at: url)
                }
            } label: {
                ZStack {
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3.0, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut, value: progress)
                    
                    RoundedRectangle(cornerRadius: 2.0)
                        .fill(Color.accentColor)
                        .frame(width: 10, height: 10)
                }
            }
        }
        .frame(width: width, height: width)
    }
    
    @ViewBuilder
    private func downloadedView() -> some View {
        ZStack {
            Circle()
                .stroke(Color.accentColor, lineWidth: lineWidth)
            
            Image(systemName: "checkmark")
                .resizable()
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 12, height: 12)
        }
        .frame(width: width, height: width)
    }
    
    @ViewBuilder
    private func pausedView(at progress: Double) -> some View {
        ZStack {
            Circle()
                .stroke(pathColor, lineWidth: lineWidth)
            
            Button {
                downloader.perform(operation: .resume, at: url)
            } label: {
                ZStack {
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3.0, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut, value: progress)
                    
                    Image(systemName: "play.fill")
                        .font(.footnote)
                        .foregroundStyle(lineColor)
                }
            }
        }
        .frame(width: width, height: width)
    }
    
    @ViewBuilder
    private func failedView() -> some View {
        Button {
            
        } label: {
            Image(systemName: "exclamationmark.triangle")
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(.regularMaterial, in: Capsule())
        }
    }
}

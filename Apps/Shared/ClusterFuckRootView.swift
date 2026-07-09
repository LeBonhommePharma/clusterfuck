import SwiftUI
import NaturalRemote

/// Shared multi-platform root: session chrome around the kernel `RemoteSessionView`.
public struct ClusterFuckRootView: View {
    @StateObject private var model = RemoteSessionViewModel()

    public init() {}

    public var body: some View {
        NavigationStack {
            RemoteSessionView(model: model)
                #if os(iOS)
                .navigationTitle("ClusterFuck")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        sessionBadge
                    }
                }
                #elseif os(macOS)
                .navigationTitle("ClusterFuck")
                .toolbar {
                    ToolbarItem {
                        sessionBadge
                    }
                }
                #else
                .navigationTitle("ClusterFuck")
                #endif
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 560)
        #endif
    }

    private var sessionBadge: some View {
        Text(model.isSessionRunning ? "LIVE" : "IDLE")
            .font(.caption.bold())
            .foregroundStyle(model.isSessionRunning ? .green : .secondary)
    }
}

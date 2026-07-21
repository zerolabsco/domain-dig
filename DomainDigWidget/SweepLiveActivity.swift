import ActivityKit
import SwiftUI
import WidgetKit

struct SweepLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SweepActivityAttributes.self) { context in
            // Lock Screen / banner presentation.
            SweepActivityBannerView(context: context)
                .padding()
                .activityBackgroundTint(Color(.systemBackground).opacity(0.85))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.title, systemImage: "arrow.trianglehead.2.clockwise")
                        .font(.caption)
                        .foregroundStyle(Color(.appTextSecondary))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.completed)/\(context.state.total)")
                        .font(.caption)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: context.state.fractionComplete)
                            .tint(Color(.statusInfo))
                        if let current = context.state.currentDomain {
                            Text(current)
                                .font(.caption2)
                                .foregroundStyle(Color(.appTextSecondary))
                                .lineLimit(1)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "arrow.trianglehead.2.clockwise")
                    .foregroundStyle(Color(.statusInfo))
            } compactTrailing: {
                Text("\(context.state.completed)/\(context.state.total)")
                    .font(.caption2)
                    .monospacedDigit()
            } minimal: {
                ProgressView(value: context.state.fractionComplete)
                    .progressViewStyle(.circular)
                    .tint(Color(.statusInfo))
            }
        }
    }
}

private struct SweepActivityBannerView: View {
    let context: ActivityViewContext<SweepActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(context.attributes.title, systemImage: "arrow.trianglehead.2.clockwise")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(.appTextSecondary))
                Spacer()
                Text("\(context.state.completed) of \(context.state.total)")
                    .font(.caption)
                    .monospacedDigit()
            }

            ProgressView(value: context.state.fractionComplete)
                .tint(Color(.statusInfo))

            HStack {
                if let current = context.state.currentDomain {
                    Text(current)
                        .font(.caption2)
                        .foregroundStyle(Color(.appTextSecondary))
                        .lineLimit(1)
                } else {
                    Text(context.state.completed >= context.state.total ? "Finished" : "Working…")
                        .font(.caption2)
                        .foregroundStyle(Color(.appTextSecondary))
                }
                Spacer()
                if context.state.changed > 0 {
                    Text("\(context.state.changed) changed")
                        .font(.caption2)
                        .foregroundStyle(Color(.statusWarning))
                }
                if context.state.warnings > 0 {
                    Text("\(context.state.warnings) warnings")
                        .font(.caption2)
                        .foregroundStyle(Color(.statusCritical))
                }
            }
        }
    }
}

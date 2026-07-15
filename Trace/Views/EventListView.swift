import SwiftData
import SwiftUI

struct EventListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TraceEvent.updatedAt, order: .reverse) private var events: [TraceEvent]
    @State private var showingNewEvent = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    hero
                    Button { showingNewEvent = true } label: {
                        HStack {
                            Text("加入一段工作對話")
                            Spacer()
                            Image(systemName: "plus")
                                .font(.headline)
                        }
                    }
                    .buttonStyle(TracePrimaryButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)

                    HStack {
                        Text("最近事件")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(TraceTheme.ink)
                        Spacer()
                        Text("查看全部")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(TraceTheme.muted)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                    if events.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(events.prefix(6)) { event in
                                NavigationLink(value: event) {
                                    TraceEventCard(event: event)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) { deleteEvent(event) } label: {
                                        Label("刪除事件", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 28)
            }
            .background(TraceTheme.paper)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: TraceEvent.self) { event in
                EventDetailView(event: event)
            }
            .sheet(isPresented: $showingNewEvent) { NewEventView() }
            .alert("無法刪除事件", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("好", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func deleteEvent(_ event: TraceEvent) {
        do {
            try EvidenceDeletionService.delete(event: event, from: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var header: some View {
        HStack {
            TraceWordmark()
            Spacer()
            Button { } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(TraceTheme.muted)
                    .frame(width: 32, height: 32)
                    .background(TraceTheme.line.opacity(0.45))
                    .clipShape(Circle())
            }
            .accessibilityLabel("更多選項")
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 28)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TraceTheme.muted)
            Text("先留下來。\n慢慢整理也可以。")
                .font(TraceTheme.titleFont(32))
                .tracking(-0.7)
                .foregroundStyle(TraceTheme.ink)
            Text("資料預設留在這台 iPhone，不會自動送給任何人。")
                .font(.system(size: 13))
                .foregroundStyle(TraceTheme.muted)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 26)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("第一件事件，從一段自己的話開始。")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(TraceTheme.ink)
            Text("你也可以稍後再從相簿或分享選單加入聊天截圖。")
                .font(.system(size: 12))
                .foregroundStyle(TraceTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.white.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .padding(.horizontal, 20)
    }
}

private struct TraceEventCard: View {
    let event: TraceEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(event.occurredAt.formatted(.dateTime.month().day().hour().minute()))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(TraceTheme.muted)
            Text(event.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(TraceTheme.ink)
            Text(event.narrative.isEmpty ? "尚未補充事件說明。" : event.narrative)
                .font(.system(size: 12))
                .foregroundStyle(TraceTheme.muted)
                .lineLimit(2)
            HStack(spacing: 5) {
                Circle().fill(TraceTheme.rust).frame(width: 5, height: 5)
                Text("\(event.attachments.count) 份材料 · \(event.attachments.filter { $0.ocrStatus == "已由使用者確認" }.count) 份已確認")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(TraceTheme.muted)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(.white.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .shadow(color: TraceTheme.ink.opacity(0.05), radius: 12, y: 5)
    }
}

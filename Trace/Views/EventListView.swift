import SwiftUI
import SwiftData

struct EventListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TraceEvent.updatedAt, order: .reverse) private var events: [TraceEvent]
    @State private var showingNewEvent = false

    var body: some View {
        NavigationStack {
            Group {
                if events.isEmpty {
                    ContentUnavailableView {
                        Label("還沒有事件", systemImage: "tray")
                    } description: {
                        Text("先記下發生的事情，或把工作對話截圖加入留痕。")
                    } actions: {
                        Button("建立第一件事件") { showingNewEvent = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(events) { event in
                            NavigationLink(value: event) {
                                EventRow(event: event)
                            }
                        }
                        .onDelete(perform: deleteEvents)
                    }
                }
            }
            .navigationTitle("留痕")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNewEvent = true } label: {
                        Label("建立事件", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: TraceEvent.self) { event in
                EventDetailView(event: event)
            }
            .sheet(isPresented: $showingNewEvent) {
                NewEventView()
            }
        }
    }

    private func deleteEvents(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(events[index])
        }
    }
}

private struct EventRow: View {
    let event: TraceEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(event.title).font(.headline)
            Text(event.occurredAt.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 5) {
                Image(systemName: "paperclip")
                Text("\(event.attachments.count) 份附件")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}

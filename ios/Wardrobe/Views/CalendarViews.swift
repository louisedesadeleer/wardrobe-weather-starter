import SwiftUI
struct WearCalendarView: View {
    @Environment(WardrobeStore.self) private var store
    @State private var month = Date()
    @State private var mode = "Month"
    @State private var forecast = ForecastService()
    @State private var selected = Date()
    @State private var choosing = false
    @State private var outfit: Outfit?
    @State private var pendingOutfit: Outfit?
    @State private var editing: WearLog?
    private let calendar = Calendar.current
    private var monthStart: Date { calendar.date(from: calendar.dateComponents([.year,.month], from: month))! }
    private var days: [Date?] {
        let leading = (calendar.component(.weekday, from: monthStart) - 2 + 7) % 7
        let count = calendar.range(of: .day, in: .month, for: monthStart)!.count
        return Array(repeating: nil, count: leading) + (0..<count).map { calendar.date(byAdding: .day, value: $0, to: monthStart) }
    }
    private var weekDays: [Date] { let offset = (calendar.component(.weekday, from: selected) - 2 + 7) % 7; let start = calendar.date(byAdding: .day, value: -offset, to: selected)!; return (0..<7).map { calendar.date(byAdding: .day, value: $0, to: start)! } }
    private var dayLogs: [WearLog] { store.library.logs.filter { $0.date == DateKey.string(selected) } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    ForecastStrip(forecast: forecast) { selected = $0; month = $0 }
                    Picker("Calendar view", selection: $mode) { Text("Month").tag("Month"); Text("Week").tag("Week") }.pickerStyle(.segmented)
                    HStack {
                        Button { if mode == "Week" { selected = calendar.date(byAdding: .day, value: -7, to: selected)!; month = selected } else { month = calendar.date(byAdding: .month, value: -1, to: month)! } } label: { Image(systemName: "chevron.left") }.accessibilityLabel(mode == "Week" ? "Previous week" : "Previous month")
                        Spacer(); Text(mode == "Week" ? weekDays[0].formatted(.dateTime.day().month(.wide)) : month.formatted(.dateTime.month(.wide).year())).font(.headline); Spacer()
                        Button { if mode == "Week" { selected = calendar.date(byAdding: .day, value: 7, to: selected)!; month = selected } else { month = calendar.date(byAdding: .month, value: 1, to: month)! } } label: { Image(systemName: "chevron.right") }.accessibilityLabel(mode == "Week" ? "Next week" : "Next month")
                    }
                    if mode == "Week" {
                        LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible())], spacing: 12) { ForEach(weekDays, id: \.self) { date in dayCell(date, weekly: true) } }
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
                            ForEach(["M","T","W","T","F","S","S"].indices, id: \.self) { index in Text(["M","T","W","T","F","S","S"][index]).font(.caption2) }
                            ForEach(days.indices, id: \.self) { index in if let date = days[index] { dayCell(date, weekly: false) } else { Color.clear.frame(height: 60) } }
                        }
                    }
                    HStack(spacing: 15) { ForEach(WearStatus.allCases) { status in Label { Text(status.title) } icon: { Circle().fill(color(status)).frame(width: 6,height: 6) }.font(.caption2) } }
                    Divider()
                    HStack { Text(selected.formatted(.dateTime.day().month(.wide))).font(Atelier.title(25)); Spacer(); Button { choosing = true } label: { Label("Add", systemImage: "plus") }.buttonStyle(AtelierButtonStyle()) }
                    if dayLogs.isEmpty { Text("Nothing logged. An empty day doesn’t mean an outfit wasn’t worn.").font(.subheadline).foregroundStyle(.secondary) }
                    ForEach(dayLogs) { log in
                        if let linked = store.library.outfits.first(where: { $0.id == log.outfitId }) {
                            Button { editing = log } label: {
                                HStack(spacing: 15) {
                                    OutfitPreview(outfit: linked).frame(width: 65,height: 96)
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(linked.name).font(Atelier.title(22))
                                        Label(log.status.title, systemImage: log.status.symbol).font(.caption).foregroundStyle(color(log.status))
                                        if !log.notes.isEmpty { Text(log.notes).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                                    }; Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding(20)
            }.background(Atelier.paper).navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Today") { selected = Date(); month = Date() } } }
            .task { await forecast.load() }
            .sheet(isPresented: $choosing, onDismiss: { outfit = pendingOutfit; pendingOutfit = nil }) { OutfitPickerView { selectedOutfit in pendingOutfit = selectedOutfit } }
            .sheet(item: $outfit) { WearEntryView(outfit: $0, initialDate: selected) }
            .sheet(item: $editing) { log in if let outfit = store.library.outfits.first(where: { $0.id == log.outfitId }) { WearEntryView(outfit: outfit, initialDate: DateKey.parse(log.date) ?? selected, existing: log) } }
        }
    }
    private func dayCell(_ date: Date, weekly: Bool) -> some View {
        let logs = store.library.logs.filter { $0.date == DateKey.string(date) }
        let first = logs.first { $0.status != .notWorn } ?? logs.first
        let outfit = store.library.outfits.first { $0.id == first?.outfitId }
        let weather = forecast.days.first { $0.date == DateKey.string(date) }
        return Button { selected = date } label: {
            VStack(spacing: 4) {
                Text(weekly ? date.formatted(.dateTime.weekday(.abbreviated).day()) : "\(calendar.component(.day, from: date))").font(weekly ? .caption : .caption2)
                if let outfit { OutfitPreview(outfit: outfit).aspectRatio(395.0/585.0, contentMode: .fit) }
                else { Rectangle().fill(Atelier.wall).aspectRatio(395.0/585.0, contentMode: .fit).overlay { Text("+").foregroundStyle(Atelier.ink.opacity(0.3)) } }
                HStack(spacing: 3) { ForEach(WearStatus.allCases.filter { status in logs.contains { $0.status == status } }) { status in Circle().fill(color(status)).frame(width: 4,height: 4) }; if logs.count > 1 { Text("+\(logs.count - 1)").font(.system(size: 8)) } }.frame(height: 6)
                if let weather { HStack(spacing: 1) { Image(systemName: weather.symbol); Text("\(Int(weather.high.rounded()))°") }.font(.system(size: weekly ? 12 : 8)).accessibilityLabel("\(weather.label), high \(Int(weather.high.rounded())) degrees") }
            }.padding(2).background(calendar.isDate(date, inSameDayAs: selected) ? Atelier.ink.opacity(0.07) : Color.clear)
                .overlay { Rectangle().stroke(calendar.isDate(date, inSameDayAs: selected) ? Atelier.ink : .clear, lineWidth: 1) }
        }.buttonStyle(.plain).accessibilityLabel(date.formatted(date: .complete, time: .omitted) + ", \(logs.count) entries")
    }
    private func color(_ status: WearStatus) -> Color { switch status { case .worn: .green; case .planned: .blue; case .notWorn: .gray } }
}
struct WearEntryView: View {
    let outfit: Outfit
    var initialDate: Date = Date()
    var existing: WearLog?
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var status: WearStatus = .worn
    @State private var notes = ""
    @State private var delete = false
    var body: some View {
        NavigationStack {
            Form {
                Section { HStack { OutfitPreview(outfit: outfit).frame(width: 80,height: 115); Text(outfit.name).font(Atelier.title(24)) } }
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date).onChange(of: date) { _, value in if DateKey.string(value) > DateKey.string(Date()) && status == .worn { status = .planned } }
                    Picker("Status", selection: $status) { ForEach(WearStatus.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                    TextField("Optional note", text: $notes, axis: .vertical).lineLimit(2...4)
                } footer: { Text("Only Worn entries count towards your wear analytics. You can log more than one outfit on the same day.") }
                if let existing { Section { Button("Remove entry", role: .destructive) { delete = true } }.confirmationDialog("Remove this calendar entry?", isPresented: $delete) { Button("Remove entry", role: .destructive) { do { try store.removeLog(existing); dismiss() } catch { store.errorMessage = error.localizedDescription } } } }
            }.scrollContentBackground(.hidden).background(Atelier.paper).navigationTitle("Wear diary").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") {
                    do {
                        if let existing {
                            let log = WearLog(date: DateKey.string(date), outfitId: outfit.id, status: status, notes: String(notes.prefix(500)), updatedAt: ISO8601DateFormatter().string(from: Date()), itemIds: existing.itemIds ?? outfit.itemIds)
                            try store.commit { library in library.logs.removeAll { $0.id == existing.id }; try library.setLog(log) }
                        } else { try store.log(outfit: outfit, date: date, status: status, notes: notes) }
                        dismiss()
                    } catch { store.errorMessage = error.localizedDescription }
                } }
            }
            .onAppear { date = initialDate; status = existing?.status ?? (DateKey.string(initialDate) > DateKey.string(Date()) ? .planned : .worn); notes = existing?.notes ?? "" }
        }
    }
}
struct OutfitPickerView: View {
    let pick: (Outfit) -> Void
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    var body: some View {
        NavigationStack {
            ScrollView { LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible())], spacing: 20) { ForEach(store.library.outfits.filter { search.isEmpty || ($0.name + $0.pieceNames).localizedCaseInsensitiveContains(search) }) { outfit in Button { dismiss(); pick(outfit) } label: { OutfitCard(outfit: outfit) }.buttonStyle(.plain) } }.padding(20) }
                .background(Atelier.paper).searchable(text: $search).navigationTitle("Choose an outfit").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

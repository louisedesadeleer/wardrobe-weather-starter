import SwiftUI
struct WeatherEditorView: View {
    let outfit: Outfit
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft = WeatherRating()
    @State private var speech = SpeechService()
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    OutfitPreview(outfit: outfit).frame(height: 200).frame(maxWidth: .infinity)
                    Text(outfit.name).font(Atelier.title(26))
                }.listRowBackground(Atelier.paper)
                Section {
                    Button { if speech.isListening { speech.stop() } else { Task { await speech.start() } } } label: { Label(speech.isListening ? "Done speaking" : "Describe the weather", systemImage: speech.isListening ? "stop.circle" : "mic") }
                    Text("Try ‘cool or mild, dry days only’.").font(.caption).foregroundStyle(.secondary)
                    if !speech.transcript.isEmpty {
                        Text(speech.transcript).font(.subheadline)
                        Button("Apply words") { draft = VoiceWeather.apply(speech.transcript, to: draft) }.disabled(speech.isListening)
                    }
                    if let error = speech.error { Text(error).font(.caption).foregroundStyle(.red) }
                } footer: { Text("Review your choices before saving. Speech uses Apple’s recognition service when needed.") }
                Section("Suitable temperatures") {
                    ForEach(Temperature.allCases) { band in
                        Toggle(isOn: Binding(get: { draft.temperatures.contains(band) }, set: { selected in
                            draft.neutral = false; draft.temperatures.removeAll { $0 == band }; if selected { draft.temperatures.append(band) }
                        })) { Label("\(band.title) · \(band.range)", systemImage: band.symbol) }
                    }
                    Toggle("Any temperature", isOn: Binding(get: { draft.neutral }, set: { draft.neutral = $0; if $0 { draft.temperatures = [] } }))
                }
                Section("Optional") {
                    Picker("Rain", selection: $draft.rain) { ForEach(Rain.allCases) { Text($0.title).tag($0) } }
                    Picker("Wind", selection: $draft.wind) { ForEach(Wind.allCases) { Text($0.title).tag($0) } }
                    TextField("A note about layers or comfort", text: $draft.notes, axis: .vertical).lineLimit(2...4).onChange(of: draft.notes) { _, value in if value.count > 500 { draft.notes = String(value.prefix(500)) } }
                }
            }.scrollContentBackground(.hidden).background(Atelier.paper)
            .navigationTitle("Outfit weather").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { do { try store.rate(outfit, rating: draft); dismiss() } catch { store.errorMessage = error.localizedDescription } }.disabled(!draft.isValid || speech.isListening) }
            }
            .onAppear { draft = store.library.ratings[outfit.id] ?? WeatherRating() }
            .onDisappear { speech.stop() }
        }
    }
}

import SwiftUI

@main struct WardrobeWeatherApp: App {
    @State private var store = WardrobeStore()
    init() { Atelier.configureNavigation() }
    var body: some Scene {
        WindowGroup {
            RootView().environment(store).tint(Atelier.ink).foregroundStyle(Atelier.ink).font(Atelier.body()).preferredColorScheme(.light)
                .alert("Something needs a look", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) { Button("OK") { store.errorMessage = nil } } message: { Text(store.errorMessage ?? "") }
        }
    }
}
struct RootView: View {
    var body: some View {
        TabView {
            WeatherHomeView().tabItem { Label("Outfits", systemImage: "cloud.sun") }
            ClosetView().tabItem { Label("Wardrobe", systemImage: "tshirt") }
            NavigationStack { BoardEditorView() }.tabItem { Label("Studio", systemImage: "square.on.square") }
            WearCalendarView().tabItem { Label("Calendar", systemImage: "calendar") }
            InsightsView().tabItem { Label("Insights", systemImage: "chart.bar.xaxis") }
        }
        .toolbarBackground(Atelier.paper, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
struct OutfitPreview: View {
    let outfit: Outfit
    var showBoardLayers = false
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Atelier.wall
                if !outfit.image.isEmpty && !showBoardLayers {
                    WardrobePhoto(source: outfit.image, label: outfit.name).padding(8)
                } else {
                    ForEach(outfit.layers) { layer in
                        WardrobePhoto(source: layer.image)
                            .frame(width: geometry.size.width * layer.width, height: geometry.size.height * layer.height)
                            .scaleEffect(x: layer.flipped ? -1 : 1, y: 1)
                            .rotationEffect(.degrees(layer.rotation))
                            .position(x: geometry.size.width * layer.centerX, y: geometry.size.height * layer.centerY)
                    }
                }
            }.clipped()
        }.aspectRatio(395.0 / 585.0, contentMode: .fit)
    }
}
struct OutfitCard: View {
    let outfit: Outfit
    @Environment(WardrobeStore.self) private var store
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            OutfitPreview(outfit: outfit)
            Text(outfit.name.uppercased()).font(Atelier.body(12)).foregroundStyle(Atelier.ink).lineLimit(1)
            if let weather = store.library.ratings[outfit.id] {
                Text(weather.neutral ? "Any temperature" : weather.temperatures.map(\.title).joined(separator: " · ")).font(.caption2).foregroundStyle(.secondary)
            } else { Text("Weather not set").font(.caption2).foregroundStyle(.secondary) }
            if outfit.missingItems > 0 { Label("Needs a check", systemImage: "exclamationmark.circle").font(.caption2).foregroundStyle(.orange) }
        }.contentShape(Rectangle())
    }
}
struct WeatherHomeView: View {
    @Environment(WardrobeStore.self) private var store
    @State private var temperature: Temperature?
    @State private var rainy = false
    @State private var windy = false
    @State private var untagged = false
    @State private var includeMissing = false
    @State private var search = ""
    @State private var selected: Outfit?
    @State private var settings = false
    @State private var organiser = true
    private var matches: [Outfit] {
        store.library.outfits.filter { outfit in
            guard includeMissing || outfit.missingItems == 0 else { return false }
            if !search.isEmpty && !(outfit.name + outfit.pieceNames + outfit.colors).localizedCaseInsensitiveContains(search) { return false }
            let rating = store.library.ratings[outfit.id]
            if untagged { return rating == nil }
            if temperature != nil || rainy || windy { return rating?.matches(temperature, rainy: rainy, windy: windy) == true }
            return true
        }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    Button { organiser = true } label: {
                        HStack { VStack(alignment: .leading, spacing: 5) { Text("Organise by weather").font(Atelier.title(23)); Text("Swipe your outfits into cold, cool, mild or hot").font(.caption2) }; Spacer(); Image(systemName: "arrow.up.right").font(.title2) }.frame(maxWidth: .infinity).padding(.vertical, 9)
                    }.buttonStyle(AtelierButtonStyle(filled: true))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            Button("All weather") { temperature = nil; untagged = false }.buttonStyle(AtelierButtonStyle(filled: temperature == nil && !untagged))
                            ForEach(Temperature.allCases) { band in
                                Button { temperature = band; untagged = false } label: { Label(band.title, systemImage: band.symbol) }.buttonStyle(AtelierButtonStyle(filled: temperature == band))
                            }
                        }
                    }
                    HStack {
                        Toggle("Rain", isOn: $rainy).toggleStyle(.button)
                        Toggle("Wind", isOn: $windy).toggleStyle(.button)
                        Toggle("Untagged", isOn: $untagged).toggleStyle(.button).onChange(of: untagged) { _, value in if value { temperature = nil; rainy = false; windy = false } }
                    }.font(.caption)
                    DisclosureGroup("Collection options") { Toggle("Include outfits with missing pieces", isOn: $includeMissing).font(.caption).padding(.top, 8) }.font(.caption).foregroundStyle(.secondary)
                    HStack { Text("\(matches.count) outfits"); Spacer(); Text("\(store.library.ratings.count) tagged") }.font(.caption).foregroundStyle(.secondary)
                    if matches.isEmpty { ContentUnavailableView("No outfits here yet", systemImage: "cloud.sun", description: Text("Try another filter, or tag some outfits for this weather.")) }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 24) {
                        ForEach(matches) { outfit in Button { selected = outfit } label: { OutfitCard(outfit: outfit) }.buttonStyle(.plain) }
                    }
                }.padding(.horizontal, 16).padding(.bottom, 24)
            }.background(Atelier.paper)
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Find an outfit, brand or colour")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { settings = true } label: { Image(systemName: "gearshape") }.accessibilityLabel("Settings and backup") } }
            .navigationDestination(isPresented: $organiser) { SwipeWeatherView() }
            .sheet(item: $selected) { OutfitDetailView(outfitId: $0.id) }
            .sheet(isPresented: $settings) { SettingsView() }
        }
    }
}
struct OutfitDetailView: View {
    let outfitId: String
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var rating = false
    @State private var log = false
    @State private var editor = false
    private var outfit: Outfit? { store.library.outfits.first { $0.id == outfitId } }
    var body: some View {
        NavigationStack {
            if let outfit {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        OutfitPreview(outfit: outfit).frame(maxHeight: 430)
                        Text(outfit.name).font(Atelier.title(34))
                        Text(outfit.brand + " · " + outfit.category).font(.caption).foregroundStyle(.secondary)
                        if outfit.missingItems > 0 { Label("\(outfit.missingItems) pieces are missing from your current wardrobe.", systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.orange) }
                        if let weather = store.library.ratings[outfit.id] {
                            Text(weather.neutral ? "Any temperature" : weather.temperatures.map(\.title).joined(separator: " · ")).font(.headline)
                            Text([weather.rain == .unknown ? "" : weather.rain.title, weather.wind == .unknown ? "" : weather.wind.title, weather.notes].filter { !$0.isEmpty }.joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary)
                            if weather.photoHash != outfit.photoHash { Text("This board changed. Check its weather choices.").font(.caption).foregroundStyle(.orange) }
                        }
                        Button { rating = true } label: { Label("Set its weather", systemImage: "cloud.sun").frame(maxWidth: .infinity) }.buttonStyle(AtelierButtonStyle())
                        Button { log = true } label: { Label("Add to calendar", systemImage: "calendar.badge.plus").frame(maxWidth: .infinity) }.buttonStyle(AtelierButtonStyle(filled: true))
                        Button(outfit.source == "created" ? "Edit this board" : "Make a variation") { editor = true }.font(.subheadline)
                        Text("Worn \(WearAnalytics(library: store.library).outfitCounts[outfit.id, default: 0]) times in your calendar").font(.caption).foregroundStyle(.secondary)
                    }.padding(20)
                }.background(Atelier.paper)
                .navigationTitle("Your outfit").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
                .sheet(isPresented: $rating) { WeatherEditorView(outfit: outfit) }
                .sheet(isPresented: $log) { WearEntryView(outfit: outfit) }
                .sheet(isPresented: $editor) { NavigationStack { BoardEditorView(initial: outfit) } }
            }
        }
    }
}

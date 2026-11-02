import SwiftUI

struct SwipeWeatherView: View {
    @Environment(WardrobeStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var fingerDown = false
    @State private var queue: [String] = []
    @State private var position = 0
    @State private var drag = CGSize.zero
    @State private var history: [SwipeAction] = []
    @State private var multiple = false
    @State private var loaded = false
    @State private var beforeEditing: WeatherRating?
    @State private var transitioning = false
    @State private var transitionTask: Task<Void, Never>?
    @State private var feedback = 0

    private struct SwipeAction {
        var outfitId: String
        var previous: WeatherRating?
        var saved: Bool
        var position: Int
    }
    private var outfit: Outfit? {
        guard queue.indices.contains(position) else { return nil }
        return store.library.outfits.first { $0.id == queue[position] }
    }
    private var suggested: Temperature? { SwipeWeather.temperature(dx: drag.width, dy: drag.height) }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 12) {
                    HStack {
                        if let outfit { Text(outfit.name.uppercased()).lineLimit(1) }
                        Spacer(minLength: 12)
                        Text("\(min(position, queue.count)) / \(queue.count)").monospacedDigit()
                    }.font(Atelier.body(11)).tracking(0.7)
                    if let outfit {
                        stage(outfit, height: max(340, min(620, geometry.size.height - 100)))
                        Text(suggested.map { "Release to save \($0.title.lowercased())" } ?? "Drag the outfit towards its weather.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    } else {
                        ContentUnavailableView("This edit is complete", systemImage: "checkmark.circle", description: Text("Every outfit in this session is tagged or skipped. You can revisit tags from Outfits."))
                        Button("Start a fresh session") { loadQueue() }.buttonStyle(AtelierButtonStyle())
                    }
                }.padding(.horizontal, 16).padding(.vertical, 12)
            }.scrollDisabled(fingerDown || transitioning)
        }
        .coordinateSpace(name: "swipe")
        .background {
            ZStack {
                Atelier.paper
                RadialGradient(colors: [Color(red: 0.57, green: 0.72, blue: 0.94), .clear], center: .bottomLeading, startRadius: 0, endRadius: 660)
                    .opacity(min(1, (0.19 + min(0.7, max(0, max(drag.height, -drag.width * 0.65) / 165))) * 1.2))
                RadialGradient(colors: [Color(red: 0.94, green: 0.67, blue: 0.55), .clear], center: .topTrailing, startRadius: 0, endRadius: 660)
                    .opacity(min(1, (0.17 + min(0.7, max(0, max(-drag.height, drag.width * 0.65) / 165))) * 1.2))
            }.ignoresSafeArea()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack {
                Button { undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                    .disabled(history.isEmpty || transitioning)
                Spacer(minLength: 8)
                Button("Weather details") {
                    beforeEditing = outfit.flatMap { store.library.ratings[$0.id] }; multiple = true
                }.disabled(outfit == nil || transitioning)
                Spacer(minLength: 8)
                Button("Skip") { skip() }.disabled(outfit == nil || transitioning)
            }.font(Atelier.body(13)).buttonStyle(.plain)
                .frame(minHeight: 52).padding(.horizontal, 20).padding(.bottom, 4)
        }
        .sensoryFeedback(.selection, trigger: suggested)
        .sensoryFeedback(.success, trigger: feedback)
        .onAppear { if !loaded { loadQueue(); loaded = true } }
        .onDisappear { transitionTask?.cancel(); transitioning = false; drag = .zero }
        .onChange(of: fingerDown) { _, down in
            // GestureState also resets when iOS interrupts a gesture without onEnded.
            if !down && !transitioning { resetDrag() }
        }
        .task(id: outfit?.id) { await preloadNextOutfits() }
        .sheet(isPresented: $multiple, onDismiss: {
            guard let outfit, let saved = store.library.ratings[outfit.id], saved != beforeEditing else { return }
            history.append(.init(outfitId: outfit.id, previous: beforeEditing, saved: true, position: position))
            position += 1; feedback += 1
        }) { if let outfit { WeatherEditorView(outfit: outfit) } }
    }

    private func stage(_ outfit: Outfit, height: CGFloat) -> some View {
        GeometryReader { geometry in
            ZStack {
                OutfitPreview(outfit: outfit)
                    .id(outfit.id)
                    .mask {
                        // Feather the board itself on all four sides, before the
                        // outer frame adds empty space around its aspect ratio.
                        LinearGradient(stops: featherStops, startPoint: .leading, endPoint: .trailing)
                            .mask {
                                LinearGradient(stops: featherStops, startPoint: .top, endPoint: .bottom)
                            }
                    }
                    .frame(width: min(300, geometry.size.width - 72), height: height - 130)
                    .blendMode(.multiply)
                    .contentShape(Rectangle())
                    .scaleEffect(drag == .zero ? 1 : 1.025)
                    .rotationEffect(.degrees(reduceMotion ? 0 : min(10, max(-10, Double(drag.width) / 24))))
                    .offset(x: drag.width * 0.94, y: drag.height * 0.94)
                    .opacity(transitioning && !reduceMotion ? 0 : 1)
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 3, coordinateSpace: .named("swipe"))
                            .updating($fingerDown) { _, state, _ in state = true }
                            .onChanged { if !transitioning { drag = $0.translation } }
                            .onEnded { value in
                                guard !transitioning else { return }
                                if let choice = SwipeWeather.temperature(dx: value.translation.width, dy: value.translation.height) { tag(choice) }
                                else { resetDrag() }
                            }
                    )
                    .accessibilityLabel("\(outfit.name). Swipe down cold, left cool, right mild, up hot. You can also tap a weather label.")
                VStack { direction(.hot, arrow: "arrow.up"); Spacer(); direction(.cold, arrow: "arrow.down") }
                HStack { direction(.cool, arrow: "arrow.left"); Spacer(); direction(.mild, arrow: "arrow.right") }
            }.frame(width: geometry.size.width, height: height)
        }.frame(height: height)
    }

    private var featherStops: [Gradient.Stop] {
        [
            .init(color: .clear, location: 0),
            .init(color: .black.opacity(0.16), location: 0.025),
            .init(color: .black.opacity(0.65), location: 0.06),
            .init(color: .black, location: 0.11),
            .init(color: .black, location: 0.89),
            .init(color: .black.opacity(0.65), location: 0.94),
            .init(color: .black.opacity(0.16), location: 0.975),
            .init(color: .clear, location: 1)
        ]
    }

    private func emoji(_ band: Temperature) -> String {
        switch band { case .cold: "❄️"; case .cool: "🌥️"; case .mild: "🌤️"; case .hot: "☀️" }
    }
    private func direction(_ band: Temperature, arrow: String) -> some View {
        Button { tag(band) } label: {
            VStack(spacing: 4) {
                HStack(spacing: 3) { Image(systemName: arrow); Text(emoji(band)) }.font(.system(size: 17))
                Text(band.title.uppercased()).font(Atelier.body(10))
                Text(band.range).font(Atelier.body(9)).fixedSize()
            }.foregroundStyle(Atelier.ink).frame(minWidth: 52, minHeight: 60)
                .background {
                    RadialGradient(colors: [.white.opacity(suggested == band ? 0.85 : 0), .clear], center: .center, startRadius: 0, endRadius: 42)
                }
        }.buttonStyle(.plain).disabled(transitioning).accessibilityLabel("Tag \(band.title), \(band.range)")
    }
    private func resetDrag() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.72)) { drag = .zero }
    }
    private func loadQueue() {
        queue = store.library.outfits.filter { store.library.ratings[$0.id] == nil && $0.missingItems == 0 }.map(\.id)
        position = 0; history = []; drag = .zero
    }
    private func tag(_ temperature: Temperature) {
        guard let outfit, !transitioning else { return }
        transitionTask?.cancel()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
            transitioning = true
            if !reduceMotion {
                switch temperature {
                case .cold: drag = CGSize(width: 0, height: 260)
                case .cool: drag = CGSize(width: -260, height: 0)
                case .mild: drag = CGSize(width: 260, height: 0)
                case .hot: drag = CGSize(width: 0, height: -260)
                }
            }
        }
        transitionTask = Task { @MainActor in
            if !reduceMotion {
                do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
            }
            guard !Task.isCancelled else { return }
            let previous = store.library.ratings[outfit.id]
            var rating = previous ?? WeatherRating()
            rating.neutral = false; rating.temperatures = [temperature]
            do {
                try store.rate(outfit, rating: rating)
                history.append(.init(outfitId: outfit.id, previous: previous, saved: true, position: position))
                position += 1; feedback += 1
            } catch { store.errorMessage = error.localizedDescription }
            // The next board starts at rest, rather than animating in from the previous exit.
            var transaction = Transaction(); transaction.disablesAnimations = true
            withTransaction(transaction) { drag = .zero; transitioning = false }
        }
    }
    private func skip() {
        guard let outfit, !transitioning else { return }
        history.append(.init(outfitId: outfit.id, previous: nil, saved: false, position: position)); position += 1
    }
    private func undo() {
        guard let action = history.last, !transitioning else { return }
        do {
            if action.saved {
                try store.commit {
                    if let previous = action.previous { $0.ratings[action.outfitId] = previous }
                    else { $0.ratings.removeValue(forKey: action.outfitId) }
                }
            }
            position = action.position; history.removeLast(); resetDrag()
        } catch { store.errorMessage = error.localizedDescription }
    }
    private func preloadNextOutfits() async {
        // A small look-ahead keeps memory/network use bounded and avoids a spinner after each swipe.
        guard loaded else { return }
        let upcoming = queue.dropFirst(position).prefix(5)
        for id in upcoming {
            guard !Task.isCancelled else { return }
            guard let outfit = store.library.outfits.first(where: { $0.id == id }) else { continue }
            let sources = outfit.image.isEmpty ? outfit.layers.map(\.image) : [outfit.image]
            for source in Set(sources) {
                guard !Task.isCancelled else { return }
                _ = try? await ImageRepository.shared.data(for: source, directory: store.directory)
            }
        }
    }
}

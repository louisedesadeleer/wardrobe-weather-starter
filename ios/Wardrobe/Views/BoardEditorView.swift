import SwiftUI
struct BoardEditorView: View {
    var initial: Outfit? = nil
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var layers: [BoardLayer] = []
    @State private var selected: String?
    @State private var picker = false
    @State private var dirty = false
    @State private var confirmClear = false
    @State private var savedMessage = ""
    @State private var saveError: String?
    @State private var savedOutfit: Outfit?
    @State private var editing: Outfit?
    @State private var initialized = false
    @State private var selfie = false
    @State private var selfiePieces: [ClosetItem] = []
    @State private var confirmSelfie = false
    private var index: Int? { layers.firstIndex { $0.id == selected } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button { picker = true } label: { Label("Add a piece", systemImage: "plus") }.buttonStyle(AtelierButtonStyle()).disabled(layers.count >= 30)
                    Spacer()
                    Button { save() } label: {
                        if !savedMessage.isEmpty && !dirty { Label("Saved", systemImage: "checkmark") }
                        else { Text("Save outfit") }
                    }.buttonStyle(AtelierButtonStyle(filled: true)).disabled(layers.isEmpty)
                }
                if !savedMessage.isEmpty && !dirty {
                    HStack {
                        Text(savedMessage).font(.caption)
                        Spacer()
                        Button("View outfit") { savedOutfit = editing }.font(.subheadline)
                    }.foregroundStyle(Atelier.ink)
                }
                Button { selfie = true } label: { Label("Start from a selfie", systemImage: "camera") }.buttonStyle(AtelierButtonStyle())
                GeometryReader { geometry in
                    ZStack {
                        Atelier.wall.onTapGesture { selected = nil }
                        ForEach(layers) { layer in
                            // Resolve bindings by identity: selection changes the array order during a gesture.
                            EditableBoardLayer(layer: Binding(get: { layers.first { $0.id == layer.id } ?? layer }, set: { updated in
                                if let index = layers.firstIndex(where: { $0.id == layer.id }) { layers[index] = updated }
                            }), canvas: geometry.size, selected: layer.id == selected, choose: { selectLayer(layer.id) }, changed: { dirty = true })
                        }
                        if layers.isEmpty { VStack(spacing: 12) { Image(systemName: "square.on.square").font(.largeTitle); Text("Start with a piece from your wardrobe.").font(.subheadline) }.foregroundStyle(.secondary).allowsHitTesting(false) }
                    }.coordinateSpace(name: "board").clipped()
                }.aspectRatio(395.0/585.0, contentMode: .fit)
                if let index {
                    VStack(spacing: 12) {
                        HStack {
                            Button { layers[index].width = max(0.08, layers[index].width * 0.9); layers[index].height = max(0.05, layers[index].height * 0.9); dirty = true } label: { Image(systemName: "minus.magnifyingglass") }.accessibilityLabel("Make smaller")
                            Button { layers[index].width = min(1.5, layers[index].width * 1.1); layers[index].height = min(1.5, layers[index].height * 1.1); dirty = true } label: { Image(systemName: "plus.magnifyingglass") }.accessibilityLabel("Make bigger")
                            Button { layers[index].flipped.toggle(); dirty = true } label: { Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right") }.accessibilityLabel("Flip piece")
                            Button { selectLayer(layers[index].id) } label: { Image(systemName: "square.3.layers.3d.top.filled") }.accessibilityLabel("Bring to front")
                            Spacer()
                            Button(role: .destructive) { layers.remove(at: index); selected = nil; dirty = true } label: { Image(systemName: "trash") }.accessibilityLabel("Remove piece")
                        }.buttonStyle(AtelierButtonStyle())
                        HStack { Image(systemName: "rotate.right"); Slider(value: Binding(get: { layers[index].rotation }, set: { layers[index].rotation = $0; dirty = true }), in: -180...180); Button("Reset") { layers[index].rotation = 0; dirty = true }.font(.caption) }
                    }
                }
                Text("Tap a piece to bring it to the front. Drag to move, pinch to resize, twist to rotate. The controls below work with one finger.").font(.caption).foregroundStyle(.secondary)
            }.padding(20)
        }.background(Atelier.paper)
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("New") { if dirty { confirmClear = true } else { clear() } } }
            if initial != nil { ToolbarItem(placement: .topBarLeading) { Button("Done") { if dirty { confirmClear = true } else { dismiss() } } } }
        }
        .confirmationDialog("Discard unsaved board changes?", isPresented: $confirmClear, titleVisibility: .visible) { Button("Discard changes", role: .destructive) { clear(); if initial != nil { dismiss() } }; Button("Keep editing", role: .cancel) {} }
        .sheet(isPresented: $selfie, onDismiss: { if !selfiePieces.isEmpty { if dirty { confirmSelfie = true } else { useSelfie() } } }) { SelfieView { selfiePieces = $0 } }
        .confirmationDialog("Replace the unsaved board with your selected pieces?", isPresented: $confirmSelfie, titleVisibility: .visible) { Button("Replace draft") { useSelfie() }; Button("Keep draft", role: .cancel) { selfiePieces = [] } }
        .sheet(isPresented: $picker) { ItemPickerView { item in
            let layer = BoardLayer(id: UUID().uuidString, itemId: item.id, image: item.image, centerX: 0.5, centerY: 0.5, width: 0.45, height: 0.38, rotation: 0, flipped: false)
            layers.append(layer); selected = layer.id; dirty = true
        } }
        .sheet(item: $savedOutfit) { OutfitDetailView(outfitId: $0.id) }
        .alert("Couldn’t save outfit", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK") { saveError = nil }
        } message: { Text(saveError ?? "") }
        .onChange(of: dirty) { _, changed in if changed { savedMessage = "" } }
        .onAppear { guard !initialized else { return }; initialized = true; if let initial { layers = initial.layers; editing = initial.source == "created" ? initial : nil; dirty = false } }
        .interactiveDismissDisabled(dirty)
    }
    private func selectLayer(_ id: String) {
        selected = id
        guard let index = layers.firstIndex(where: { $0.id == id }), index != layers.count - 1 else { return }
        layers.append(layers.remove(at: index)); dirty = true
    }
    private func useSelfie() {
        clear()
        layers = selfiePieces.enumerated().map { index, item in BoardLayer(id: UUID().uuidString, itemId: item.id, image: item.image, centerX: selfiePieces.count == 1 ? 0.5 : (index % 2 == 0 ? 0.3 : 0.7), centerY: min(0.85, 0.22 + Double(index / 2) * 0.24), width: 0.4, height: 0.3, rotation: 0, flipped: false) }
        dirty = true; selfiePieces = []
    }
    private func clear() { layers = []; selected = nil; editing = nil; dirty = false; savedMessage = "" }
    private func save() {
        do {
            editing = try store.saveBoard(name: "", layers: layers, editing: editing)
            dirty = false; saveError = nil; savedMessage = "Saved to Outfits."
        } catch {
            savedMessage = ""; saveError = error.localizedDescription
        }
    }
}
struct EditableBoardLayer: View {
    @Binding var layer: BoardLayer
    let canvas: CGSize
    let selected: Bool
    let choose: () -> Void
    let changed: () -> Void
    @State private var start: CGPoint?
    @State private var initialSize: CGSize?
    @State private var initialRotation: Double?
    var body: some View {
        WardrobePhoto(source: layer.image, label: "Outfit piece")
            .frame(width: canvas.width * layer.width, height: canvas.height * layer.height)
            .scaleEffect(x: layer.flipped ? -1 : 1, y: 1)
            .overlay { Rectangle().strokeBorder(selected ? Atelier.ink.opacity(0.65) : .clear, style: StrokeStyle(lineWidth: 1, dash: [4,3])) }
            .rotationEffect(.degrees(layer.rotation))
            .contentShape(Rectangle())
            .onTapGesture(perform: choose)
            .highPriorityGesture(DragGesture(minimumDistance: 3, coordinateSpace: .named("board")).onChanged { value in
                if start == nil { choose(); start = CGPoint(x: layer.centerX, y: layer.centerY) }
                guard let start else { return }
                layer.centerX = min(1.1, max(-0.1, start.x + value.translation.width / canvas.width))
                layer.centerY = min(1.1, max(-0.1, start.y + value.translation.height / canvas.height)); changed()
            }.onEnded { _ in start = nil })
            .simultaneousGesture(MagnifyGesture().onChanged { value in
                choose(); if initialSize == nil { initialSize = CGSize(width: layer.width, height: layer.height) }
                guard let initialSize else { return }
                let factor = min(min(1.5 / initialSize.width, 1.5 / initialSize.height), max(max(0.08 / initialSize.width, 0.05 / initialSize.height), value.magnification))
                layer.width = initialSize.width * factor; layer.height = initialSize.height * factor; changed()
            }.onEnded { _ in initialSize = nil })
            .simultaneousGesture(RotateGesture().onChanged { value in
                choose(); if initialRotation == nil { initialRotation = layer.rotation }
                let angle = (initialRotation ?? 0) + value.rotation.degrees
                layer.rotation = ((angle + 180).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) - 180; changed()
            }.onEnded { _ in initialRotation = nil })
            .position(x: canvas.width * layer.centerX, y: canvas.height * layer.centerY)
            .accessibilityAddTraits(.isButton)
    }
}
struct ItemPickerView: View {
    let pick: (ClosetItem) -> Void
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var category = "All"
    var body: some View {
        NavigationStack {
            ScrollView {
                Picker("Category", selection: $category) { Text("All pieces").tag("All"); ForEach(Array(Set(closetCategories + store.library.items.map(\.category))).sorted(), id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu).padding(.horizontal, 18)
                LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible())], spacing: 18) {
                    ForEach(store.library.items.filter { (category == "All" || $0.category == category) && (search.isEmpty || ($0.name + $0.brand + $0.colors).localizedCaseInsensitiveContains(search)) }) { item in
                        Button { pick(item); dismiss() } label: { VStack { WardrobePhoto(source: item.image, label: item.name).frame(height: 100).frame(maxWidth: .infinity).background(Atelier.wall); Text(item.name).font(.caption2).lineLimit(2) } }.buttonStyle(.plain)
                    }
                }.padding(18)
            }.background(Atelier.paper).navigationTitle("Choose a piece").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

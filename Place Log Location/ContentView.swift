import SwiftUI
import Observation

// MARK: - Модели данных
struct Location: Codable, Identifiable {
    let id = UUID()
    var name: String
    var waterType: WaterType
    var season: Season
    var notes: String
    var visits: [Visit]
    
    var visitsCount: Int { visits.count }
    var lastVisitDate: Date? { visits.max(by: { $0.date < $1.date })?.date }
}

enum WaterType: String, CaseIterable, Codable {
    case river = "River"
    case lake = "Lake"
    case pond = "Pond"
    case sea = "Sea"
}

enum Season: String, CaseIterable, Codable {
    case spring = "Spring"
    case summer = "Summer"
    case autumn = "Autumn"
    case winter = "Winter"
}

struct Visit: Codable, Identifiable {
    let id = UUID()
    var date: Date
    var fishTypes: [FishType]
    var result: ResultType
    var notes: String
}

enum FishType: String, CaseIterable, Codable {
    case perch = "Perch"
    case pike = "Pike"
    case carp = "Carp"
    case trout = "Trout"
    case catfish = "Catfish"
}

enum ResultType: String, CaseIterable, Codable {
    case poor = "Poor"
    case normal = "Normal"
    case good = "Good"
}

// MARK: - Главная ViewModel
@MainActor
class AppViewModel: ObservableObject {
    @Published var locations: [Location] = []
    @Published var selectedTab: Tab = .locations
    @Published var searchText: String = ""
    
    private let locationsKey = "savedLocations"
    
    init() {
        loadData()
    }
    
    // MARK: - CRUD операции
    func addLocation(_ location: Location) {
        locations.append(location)
        saveData()
    }
    
    func updateLocation(id: UUID, _ update: (inout Location) -> Void) {
        if let index = locations.firstIndex(where: { $0.id == id }) {
            update(&locations[index])
            saveData()
        }
    }
    
    func deleteLocation(id: UUID) {
        locations.removeAll { $0.id == id }
        saveData()
    }
    
    func addVisit(to locationId: UUID, _ visit: Visit) {
        if let index = locations.firstIndex(where: { $0.id == locationId }) {
            locations[index].visits.append(visit)
            saveData()
        }
    }
    
    func updateVisit(locationId: UUID, visitId: UUID, _ update: (inout Visit) -> Void) {
        guard let locationIndex = locations.firstIndex(where: { $0.id == locationId }),
              let visitIndex = locations[locationIndex].visits.firstIndex(where: { $0.id == visitId }) else { return }
        
        update(&locations[locationIndex].visits[visitIndex])
        saveData()
    }
    
    func deleteVisit(locationId: UUID, visitId: UUID) {
        guard let locationIndex = locations.firstIndex(where: { $0.id == locationId }) else { return }
        locations[locationIndex].visits.removeAll { $0.id == visitId }
        saveData()
    }
    
    // MARK: - Статистика
    var totalLocations: Int { locations.count }
    var totalVisits: Int { locations.reduce(0) { $0 + $1.visitsCount } }
    
    var bestSeason: Season {
        let seasonCounts = seasonStats()
        return seasonCounts.max(by: { $0.value < $1.value })?.key ?? .summer
    }
    
    var mostCommonFish: FishType {
        let fishCounts = fishStats()
        return fishCounts.max(by: { $0.value < $1.value })?.key ?? .perch
    }
    
    func seasonStats() -> [Season: Int] {
        let stats = locations.reduce(into: [Season: Int]()) { result, location in
            result[location.season, default: 0] += 1
        }
        return stats
    }
    
    func fishStats() -> [FishType: Int] {
        let allFish = locations.flatMap { $0.visits.flatMap { $0.fishTypes } }
        return allFish.reduce(into: [FishType: Int]()) { result, fish in
            result[fish, default: 0] += 1
        }
    }
    
    var filteredLocations: [Location] {
        searchText.isEmpty ? locations :
        locations.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    // MARK: - UserDefaults
    private func saveData() {
        if let data = try? JSONEncoder().encode(locations) {
            UserDefaults.standard.set(data, forKey: locationsKey)
        }
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: locationsKey),
           let decoded = try? JSONDecoder().decode([Location].self, from: data) {
            locations = decoded
        }
    }
    
    // MARK: - Reset
    func resetAllData() {
        locations = []
        UserDefaults.standard.removeObject(forKey: locationsKey)
    }
}

enum Tab: String, CaseIterable {
    case locations = "map.fill"
    case log = "book.fill"
    case stats = "chart.bar.fill"
    case settings = "gear"
}

// MARK: - Главный экран
// MARK: - ГЛАВНЫЙ ContentView с NavigationStack
struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    
    var body: some View {
        NavigationStack {  // ✅ ОСНОВНАЯ ПРОБЛЕМА - добавь это!
            ZStack {
                Color(hex: "E8F4FD").ignoresSafeArea()
                
                Group {
                    switch viewModel.selectedTab {
                    case .locations:
                        LocationsView(viewModel: viewModel)
                    case .log:
                        LogView(viewModel: viewModel)
                    case .stats:
                        StatsView(viewModel: viewModel)
                    case .settings:
                        SettingsView(viewModel: viewModel)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                CustomTabBar(selectedTab: $viewModel.selectedTab)
            }
            .overlay(alignment: .bottomTrailing) {
                AddLocationButton(viewModel: viewModel)  // ✅ Передаем viewModel
                    .padding(.trailing, 20)
                    .padding(.bottom, 90)
            }
        }
    }
}


// MARK: - Кастомный TabBar
struct CustomTabBar: View {
    @Binding var selectedTab: Tab
    
    var body: some View {
        HStack(spacing: 40) {
            ForEach(Tab.allCases, id: \.self) { tab in
                VStack(spacing: 4) {
                    Image(systemName: tab.rawValue)
                        .font(.system(size: 24, weight: tab == selectedTab ? .semibold : .medium))
                        .foregroundStyle(tab == selectedTab ? .blue : .gray)
                        .frame(height: 30)
                    
                    Capsule()
                        .fill(tab == selectedTab ? Color.blue : Color.clear)
                        .frame(height: 4)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .frame(maxHeight: 80)
    }
}

// MARK: - Обновленная LocationsView с поиском и навигацией
struct LocationsView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        ZStack {
            Color.clear
            
            VStack(spacing: 0) {
                headerView
                ScrollView {
                    if viewModel.filteredLocations.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 16, pinnedViews: []) {
                            ForEach(viewModel.filteredLocations) { location in
                                LocationCardView(
                                    location: location,
                                    viewModel: viewModel
                                )
                                // ✅ НАВИГАЦИЯ через NavigationLink в LocationCardView
                            }
                            
                            Color.clear.frame(height: 80)
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle("My Locations")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchText, prompt: "Search locations")
    }
    
    private var headerView: some View {
        HStack {
            Text("My Locations")
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
            
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No locations yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
            
            Text("Tap + to add your first fishing spot")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxHeight: .infinity)
    }
}

struct LocationCardView: View {
    let location: Location
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        NavigationLink(
            destination: LocationDetailsView(
                locationId: location.id,
                viewModel: viewModel
            )
        ) {
            HStack(alignment: .top, spacing: 16) {
                // Иконка водоема
                Image(systemName: location.waterType.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)
                    .frame(width: 60, height: 60)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(.blue.opacity(0.3), lineWidth: 2)
                    )
                
                // Основная информация
                VStack(alignment: .leading, spacing: 8) {
                    // Название
                    Text(location.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fontDesign(.rounded)
                    
                    // Статистика
                    HStack(spacing: 16) {
                        StatBadgeView(
                            icon: "calendar.badge.clock",
                            title: "\(location.visitsCount)",
                            color: .blue
                        )
                        
                        StatBadgeView(
                            icon: "leaf.fill",
                            title: location.season.rawValue,
                            color: .green
                        )
                        
                        if let lastVisit = location.lastVisitDate {
                            StatBadgeView(
                                icon: "clock.fill",
                                title: dateFormatter.string(from: lastVisit),
                                color: .orange
                            )
                        }
                    }
                    .font(.subheadline)
                    
                    // Заметки
                    if !location.notes.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text(location.notes.prefix(80) + (location.notes.count > 80 ? "..." : ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Стрелка
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                    .opacity(0.7)
            }
            .padding()
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.ultraThinMaterial, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle()) // Убираем стандартный стиль NavigationLink
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

// MARK: - Вспомогательный компонент статистики
struct StatBadgeView: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

struct AllVisitsView: View {
    let location: Location
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "E8F4FD").ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(location.visits.sorted(by: { $0.date > $1.date })) { visit in
                            VisitPreviewCard(visit: visit)
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        viewModel.deleteVisit(locationId: location.id, visitId: visit.id)
                                    }
                                }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("All Visits (\(location.visitsCount))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}


struct AddVisitView: View {
    let locationId: UUID
    let locationName: String
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var date = Date()
    @State private var fishTypes: Set<FishType> = []
    @State private var result: ResultType = .normal
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "E8F4FD").ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text("Visit to \(locationName)")
                        .font(.title2.weight(.semibold))
                    
                    formFields
                    Spacer()
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("New Visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private var formFields: some View {
        VStack(spacing: 20) {
            DatePicker(
                "Date",
                selection: $date,
                displayedComponents: [.date]
            )
            .datePickerStyle(.compact)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Fish caught")
                    .font(.caption.weight(.medium))
                HStack {
                    ForEach(FishType.allCases, id: \.self) { fish in
                        Button(fish.rawValue) {
                            if fishTypes.contains(fish) {
                                fishTypes.remove(fish)
                            } else {
                                fishTypes.insert(fish)
                            }
                        }
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            fishTypes.contains(fish) ? Color.blue.opacity(0.2) : Color(.systemGray6),
                            in: Capsule()
                        )
                        .foregroundStyle(fishTypes.contains(fish) ? .blue : .secondary)
                    }
                }
            }
            
            Picker("Result", selection: $result) {
                ForEach(ResultType.allCases, id: \.self) { resultType in
                    Text(resultType.rawValue).tag(resultType)
                }
            }
            .pickerStyle(.segmented)
            
            TextField("Notes", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }
    
    private var actionButtons: some View {
        Button("Save Visit") {
            let visit = Visit(
                date: date,
                fishTypes: Array(fishTypes),
                result: result,
                notes: notes
            )
            viewModel.addVisit(to: locationId, visit)
            dismiss()
        }
        .buttonStyle(.borderedProminent)
        .disabled(fishTypes.isEmpty)
    }
}


struct LocationDetailsView: View {
    let locationId: UUID
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var location: Location?
    @State private var showingAddVisit = false
    @State private var showingAllVisits = false
    
    var body: some View {
        ZStack {
            Color(hex: "E8F4FD").ignoresSafeArea()
            
            Group {
                if let location = location {
                    ScrollView {
                        VStack(spacing: 24) {
                            headerSection(location: location)
                            infoSection(location: location)
                            visitsSection(location: location)
                        }
                        .padding()
                    }
                } else {
                    ProgressView("Loading...")
                        .frame(maxHeight: .infinity)
                }
            }
        }
        .navigationTitle(location?.name ?? "Location")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Delete") {
                    viewModel.deleteLocation(id: locationId)
                    dismiss()
                }
                .foregroundStyle(.red)
            }
        }
        .sheet(isPresented: $showingAddVisit) {
            if let location = location {
                AddVisitView(
                    locationId: locationId,
                    locationName: location.name,
                    viewModel: viewModel
                )
            }
        }
        .sheet(isPresented: $showingAllVisits) {
            if let location = location {
                AllVisitsView(location: location, viewModel: viewModel)
            }
        }
        .task { loadLocation() }
    }
    
    private func loadLocation() {
        location = viewModel.locations.first { $0.id == locationId }
    }
    
    private func headerSection(location: Location) -> some View {
        VStack(spacing: 16) {
            Image(systemName: location.waterType.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundStyle(.blue)
                .background(.ultraThinMaterial, in: Circle())
            
            VStack(spacing: 8) {
                Text(location.name)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)
                
                HStack {
                    Label(location.waterType.rawValue, systemImage: location.waterType.icon)
                        .foregroundStyle(.blue)
                    Spacer()
                    Label(location.season.rawValue, systemImage: location.season.icon ?? "leaf")
                        .foregroundStyle(.green)
                }
                .font(.subheadline.weight(.medium))
            }
        }
    }
    
    private func infoSection(location: Location) -> some View {
        GroupBoxView(title: "Info") {
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(icon: "calendar.badge.clock", title: "Visits", value: "\(location.visitsCount)")
                
                if let lastVisit = location.lastVisitDate {
                    InfoRow(
                        icon: "clock.fill",
                        title: "Last visit",
                        value: dateFormatter.string(from: lastVisit)
                    )
                }
                
                if !location.notes.isEmpty {
                    InfoRow(
                        icon: "note.text",
                        title: "Notes",
                        value: location.notes
                    )
                }
            }
        }
    }
    
    private func visitsSection(location: Location) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Visits (\(location.visitsCount))")
                    .font(.headline.weight(.semibold))
                Spacer()
                Button("All") { showingAllVisits = true }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.blue)
            }
            
            if location.visits.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "fish.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                    Text("No visits yet")
                        .foregroundStyle(.secondary)
                    Button("Add Visit") { showingAddVisit = true }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(location.visits.sorted(by: { $0.date > $1.date })) { visit in
                        VisitPreviewCard(visit: visit)
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    viewModel.deleteVisit(locationId: locationId, visitId: visit.id)
                                }
                            }
                    }
                }
            }
        }
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}


// MARK: - Вспомогательные компоненты
struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
    }
}

struct GroupBoxView<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline.weight(.semibold))
            
            content
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.ultraThinMaterial, lineWidth: 1)
        )
    }
}

struct VisitPreviewCard: View {
    let visit: Visit
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: visit.result.icon)
                .font(.title3)
                .foregroundStyle(visit.result.color)
                .frame(width: 44, height: 44)
                .background(visit.result.color.opacity(0.1), in: Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(dateFormatter.string(from: visit.date))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                HStack {
                    // ✅ ИСПРАВЛЕНО: используем id: \.self для enum
                    ForEach(visit.fishTypes.prefix(2), id: \.self) { fish in
                        Label(fish.rawValue, systemImage: "fish.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    if visit.fishTypes.count > 2 {
                        Text("+\(visit.fishTypes.count - 2)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if !visit.notes.isEmpty {
                Text(visit.notes.prefix(40) + "...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

// MARK: - Расширения для иконок и цветов
extension ResultType {
    var icon: String {
        switch self {
        case .poor: return "xmark.circle"
        case .normal: return "circle"
        case .good: return "checkmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .poor: return .red
        case .normal: return .orange
        case .good: return .green
        }
    }
}

extension WaterType {
    var icon: String {
        switch self {
        case .river: return "waveform"
        case .lake: return "drop.fill"
        case .pond: return "drop"
        case .sea: return "wind"
        }
    }
}



// Заглушки остальных экранов
struct LogView: View {
    let viewModel: AppViewModel
    
    var body: some View {
        ZStack {
            Color(hex: "E8F4FD").ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView {
                    if viewModel.totalVisits == 0 {
                        emptyState
                    } else {
                        visitsList
                    }
                }
            }
        }
        .navigationTitle("Fishing Log")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Fishing Log")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                
                Text("\(viewModel.totalVisits) visits")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    private var visitsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.locations) { location in
                if !location.visits.isEmpty {
                    ForEach(location.visits.sorted(by: { $0.date > $1.date })) { visit in
                        VisitLogCardSimple(
                            visit: visit,
                            locationName: location.name
                        )
                    }
                }
            }
        }
        .padding()
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No visits yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
            
            Text("Add visits to your locations to see fishing history")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxHeight: .infinity)
    }
}

struct VisitLogCardSimple: View {
    let visit: Visit
    let locationName: String
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    var body: some View {
        HStack(spacing: 12) {
            // Иконка результата
            Image(systemName: visit.result.icon)
                .font(.title2)
                .foregroundStyle(visit.result.color)
                .frame(width: 44, height: 44)
                .background(visit.result.color.opacity(0.1), in: Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(locationName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text(dateFormatter.string(from: visit.date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack {
                    ForEach(visit.fishTypes.prefix(2), id: \.self) { fish in
                        Label(fish.rawValue, systemImage: "fish")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
            
            Spacer()
            
            Text(visit.result.rawValue)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(visit.result.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(visit.result.color.opacity(0.1), in: Capsule())
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}


struct StatsView: View {
    let viewModel: AppViewModel
    
    var body: some View {
        ZStack {
            Color(hex: "E8F4FD").ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 28) {
                    headerStats
                    generalStats
                    seasonStats
                    fishStats
                    bestResults
                    
                    Color.clear.frame(height: 100)
                }
                .padding()
            }
        }
        .navigationTitle("Statistics")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var headerStats: some View {
        VStack(spacing: 16) {
            Text("Fishing Stats")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.primary)
            
            Text("\(viewModel.totalVisits) visits across \(viewModel.totalLocations) locations")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var generalStats: some View {
        Grid {
            GridRow {
                StatCard(title: "Locations", value: "\(viewModel.totalLocations)", icon: "mappin.and.ellipse", color: .blue)
                StatCard(title: "Total Visits", value: "\(viewModel.totalVisits)", icon: "calendar.badge.clock", color: .green)
            }
            
            GridRow {
                StatCard(title: "Best Season", value: viewModel.bestSeason.rawValue, icon: viewModel.bestSeason.icon, color: .orange)
                StatCard(title: "Top Fish", value: viewModel.mostCommonFish.rawValue, icon: "fish.fill", color: .indigo)
            }
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
    }
    
    private var seasonStats: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("By Season")
                .font(.headline.weight(.semibold))
            
            let seasonStats = viewModel.seasonStats()
            HStack(spacing: 12) {
                ForEach(Season.allCases, id: \.self) { season in
                    SeasonStatCard(
                        season: season,
                        count: seasonStats[season] ?? 0,
                        total: viewModel.totalVisits
                    )
                }
            }
        }
    }
    
    private var fishStats: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Most Caught Fish")
                .font(.headline.weight(.semibold))
            
            let fishStats = viewModel.fishStats()
            let sortedFish = fishStats.sorted { $0.value > $1.value }
            
            LazyVStack(spacing: 8) {
                ForEach(Array(sortedFish.prefix(5)), id: \.key) { fish, count in
                    FishStatRow(fish: fish, count: count)
                }
            }
        }
    }
    
    private var bestResults: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Best Results")
                .font(.headline.weight(.semibold))
            
            let resultStats = resultStats()
            HStack(spacing: 12) {
                ForEach(ResultType.allCases, id: \.self) { result in
                    ResultStatCard(result: result, count: resultStats[result] ?? 0)
                }
            }
        }
    }
    
    private func resultStats() -> [ResultType: Int] {
        viewModel.locations.flatMap { $0.visits }.reduce(into: [ResultType: Int]()) { result, visit in
            result[visit.result, default: 0] += 1
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 50, height: 50)
                .background(color.opacity(0.1), in: Circle())
            
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SeasonStatCard: View {
    let season: Season
    let count: Int
    let total: Int
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: season.icon)
                .font(.title3)
                .foregroundStyle(seasonColor)
            
            Text("\(count)")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            
            Text(season.rawValue)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var seasonColor: Color {
        switch season {
        case .spring: return .green
        case .summer: return .orange
        case .autumn: return .yellow
        case .winter: return .blue
        }
    }
}

struct FishStatRow: View {
    let fish: FishType
    let count: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "fish.fill")
                .foregroundStyle(.blue)
            
            Text(fish.rawValue)
                .font(.body.weight(.medium))
            
            Spacer()
            
            Text("\(count)")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.blue)
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ResultStatCard: View {
    let result: ResultType
    let count: Int
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: result.icon)
                .font(.title3)
                .foregroundStyle(result.color)
            
            Text("\(count)")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            
            Text(result.rawValue)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(result.color.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct SettingsView: View {
    let viewModel: AppViewModel
    @AppStorage("showDetailedStats") private var showDetailedStats = true
    @AppStorage("darkMode") private var darkMode = false
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showingResetAlert = false
    
    var body: some View {
        ZStack {
            Color(hex: "E8F4FD").ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    
                    dataSection
                    supportSection
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reset All Data", isPresented: $showingResetAlert) {
            Button("Reset All", role: .destructive) {
                viewModel.resetAllData()
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fish Location Log")
                .font(.title2.weight(.bold))
            
            Text("Version 1.0")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var generalSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            
            Toggle("Detailed Stats", isOn: $showDetailedStats)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
    }
    
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Appearance")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            
            Toggle("Dark Mode", isOn: $darkMode)
                .toggleStyle(SwitchToggleStyle(tint: .indigo))
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
    }
    
    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Data")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            
            Button("Reset All Data") {
                showingResetAlert = true
            }
            .font(.headline.weight(.semibold))
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
    }
    
    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Support")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            
            Button(action: openPrivacyPolicy) {
                Label("Privacy Policy", systemImage: "lock.shield")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            
            Button(action: openSupport) {
                Label("Contact Support", systemImage: "envelope")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
    }
    
    private func openPrivacyPolicy() {
        if let url = URL(string: "https://yourwebsite.com/privacy-policy") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openSupport() {
        if let url = URL(string: "mailto:support@yourfishingapp.com") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openAppReview() {
        if let url = URL(string: "https://apps.apple.com/app/id123456789?action=write-review") {
            UIApplication.shared.open(url)
        }
    }
}


// MARK: - Функциональная кнопка +Add
struct AddLocationButton: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showingAddSheet = false
    
    var body: some View {
        Button {
            showingAddSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Circle().fill(.blue))
                .shadow(color: .blue.opacity(0.3), radius: 20)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddLocationView(viewModel: viewModel)  // ✅ Работает!
        }
    }
}

// MARK: - Add Location Screen
struct AddLocationView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var waterType: WaterType = .lake
    @State private var season: Season = .summer
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "E8F4FD").ignoresSafeArea()
                
                VStack(spacing: 24) {
                    formFields
                    Spacer()
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var formFields: some View {
        VStack(spacing: 20) {
            CustomTextField(
                title: "Location name",
                text: $name,
                placeholder: "Forest Lake",
                icon: "mappin.and.ellipse"
            )
            
            // ✅ Water type - ПРОСТОЙ Menu
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(.blue)
                        .font(.caption.weight(.medium))
                    Text("Water type")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                
                Menu {
                    ForEach(WaterType.allCases, id: \.self) { type in
                        Button(type.rawValue) { waterType = type }
                    }
                } label: {
                    HStack {
                        Image(systemName: waterType.icon)
                            .foregroundStyle(.blue)
                        Text(waterType.rawValue)
                            .font(.body)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                }
            }
            
            // ✅ Season - ПРОСТОЙ Menu
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(.green)
                        .font(.caption.weight(.medium))
                    Text("Season")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                
                Menu {
                    ForEach(Season.allCases, id: \.self) { seasonType in
                        Button(seasonType.rawValue) { season = seasonType }
                    }
                } label: {
                    HStack {
                        Image(systemName: season.icon)
                            .foregroundStyle(.green)
                        Text(season.rawValue)
                            .font(.body)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                }
            }
            
            CustomTextArea(
                title: "Notes",
                text: $notes,
                placeholder: "Access road, depth, weather, features..."
            )
        }
    }

    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                saveLocation()
            } label: {
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                    Text("Save Location")
                }
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.blue)
                        .shadow(color: .blue.opacity(0.3), radius: 12)
                )
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            
            Button("Cancel") { dismiss() }
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private func saveLocation() {
        let location = Location(
            name: name.trimmingCharacters(in: .whitespaces),
            waterType: waterType,
            season: season,
            notes: notes.trimmingCharacters(in: .whitespaces),
            visits: []
        )
        viewModel.addLocation(location)
        dismiss()
    }
}

// MARK: - Кастомные компоненты формы
struct CustomTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                    .font(.caption.weight(.medium))
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
            }
            
            TextField("", text: $text)
                .font(.body)
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .overlay(alignment: .leading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                    }
                }
        }
        .animation(.default, value: text)
    }
}

struct CustomTextArea: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .padding(14)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .frame(minHeight: 100)
                
                if text.isEmpty {
                    Text(placeholder)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(14)
                        .allowsHitTesting(false)
                }
            }
        }
    }
}

struct CustomPickerField: View {
    let title: String
    let icon: String
    let options: [(String, String)] // [(текст, иконка)]
    @Binding var selectedIndex: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Заголовок
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                    .font(.caption.weight(.medium))
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
            }
            
            // ПРОСТОЙ Menu
            Menu {
                ForEach(0..<options.count, id: \.self) { index in
                    Button(options[index].0) {
                        selectedIndex = index
                    }
                }
            } label: {
                HStack {
                    Text(options[selectedIndex].0)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            }
        }
    }
}


// MARK: - Расширения для Season
extension Season {
    var icon: String {
        switch self {
        case .spring: return "leaf"
        case .summer: return "sun.max.fill"
        case .autumn: return "leaf.fill"
        case .winter: return "snowflake"
        }
    }
}


// MARK: - Extensions
extension Tab {
    static var allCases: [Tab] {
        [.locations, .log, .stats, .settings]
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}

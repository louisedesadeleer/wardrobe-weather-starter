import Foundation
import SwiftUI

struct ForecastDay: Identifiable {
    var date: String; var code: Int; var high: Double; var low: Double; var rain: Int?
    var id: String { date }
    var symbol: String { switch code { case 0: "sun.max"; case 1...3: "cloud.sun"; case 45,48: "cloud.fog"; case 71...77,85,86: "cloud.snow"; case 95...99: "cloud.bolt.rain"; default: "cloud.rain" } }
    var label: String { switch code { case 0: "Clear"; case 1...3: "Cloudy"; case 45,48: "Fog"; case 71...77,85,86: "Snow"; case 95...99: "Thunderstorms"; default: "Rain" } }
}
@MainActor @Observable final class ForecastService {
    var days: [ForecastDay] = []
    var message = "Loading forecast…"
    private var fetched: Date?
    private var busy = false
    func load(force: Bool = false) async {
        if busy || (!force && fetched.map { Date().timeIntervalSince($0) < 1800 } == true) { return }
        busy = true; defer { busy = false }
        struct Result: Decodable { struct Daily: Decodable { var time: [String]; var weather_code: [Int]; var temperature_2m_max: [Double]; var temperature_2m_min: [Double]; var precipitation_probability_max: [Int?] }; var daily: Daily }
        do {
            let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=38.7223&longitude=-9.1393&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=Europe%2FLisbon&forecast_days=7")!
            var request = URLRequest(url: url); request.timeoutInterval = 20
            let (data,response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let d = try JSONDecoder().decode(Result.self, from: data).daily
            guard [d.weather_code.count,d.temperature_2m_max.count,d.temperature_2m_min.count,d.precipitation_probability_max.count].allSatisfy({ $0 == d.time.count }) else { throw URLError(.cannotParseResponse) }
            days = d.time.indices.map { ForecastDay(date: d.time[$0], code: d.weather_code[$0], high: d.temperature_2m_max[$0], low: d.temperature_2m_min[$0], rain: d.precipitation_probability_max[$0]) }; fetched = Date(); message = ""
        } catch { days = []; message = "Forecast unavailable. Tap refresh to retry." }
    }
}
struct ForecastStrip: View {
    let forecast: ForecastService
    let choose: (Date) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text("Lisbon · upcoming days").font(.caption); Spacer(); Button { Task { await forecast.load(force: true) } } label: { Image(systemName: "arrow.clockwise") }.accessibilityLabel("Refresh forecast") }
            if forecast.days.isEmpty { Text(forecast.message).font(.caption).foregroundStyle(.secondary) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) { ForEach(forecast.days) { day in
                    Button { if let date = DateKey.parse(day.date) { choose(date) } } label: {
                        VStack(spacing: 8) {
                            Text((DateKey.parse(day.date) ?? Date()).formatted(.dateTime.weekday(.abbreviated).day())).font(.caption2)
                            Image(systemName: day.symbol).font(.title3).accessibilityLabel(day.label)
                            Text("\(Int(day.high.rounded()))° / \(Int(day.low.rounded()))°").font(.caption)
                            Text(day.rain.map { "\($0)% rain" } ?? "Rain —").font(.caption2)
                        }.frame(width: 74).padding(.vertical, 12).background(Atelier.wall)
                    }.buttonStyle(.plain)
                } }
            }
            Link("Forecast by Open-Meteo · Lisbon time", destination: URL(string: "https://open-meteo.com/")!).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

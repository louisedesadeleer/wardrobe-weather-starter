import Foundation
public enum VoiceWeather {
    public static func apply(_ sentence: String, to original: WeatherRating) -> WeatherRating {
        var result = original
        let text = sentence.lowercased().replacingOccurrences(of: "-", with: " ")
        let weather = text.components(separatedBy: "note:").first ?? text
        let clauses = weather.components(separatedBy: CharacterSet(charactersIn: ",.;!?"))
        var picked: [Temperature] = []
        for clause in clauses {
            var negative = false
            for token in clause.split(whereSeparator: { !$0.isLetter }).map(String.init) {
                if ["no","not","never","avoid","except"].contains(token) { negative = true }
                if token == "but" { negative = false }
                if !negative, let t = Temperature(rawValue: token), !picked.contains(t) { picked.append(t) }
            }
        }
        if !picked.isEmpty { result.temperatures = picked; result.neutral = false }
        if ["any temperature","all temperatures","temperature neutral"].contains(where: weather.contains), !weather.contains("not") { result.neutral = true; result.temperatures = [] }
        if ["dry days","dry only","no rain","avoid rain","not waterproof"].contains(where: weather.contains) { result.rain = .dryOnly }
        else if weather.contains("light rain") && !weather.contains("not light rain") { result.rain = .lightRain }
        else if ["rain ready","waterproof","rain is fine"].contains(where: weather.contains) && !weather.contains("not") { result.rain = .rainReady }
        if ["no wind","avoid wind","not windproof"].contains(where: weather.contains) { result.wind = .avoidWind }
        else if ["wind is fine","windproof"].contains(where: weather.contains) && !weather.contains("not") { result.wind = .windOK }
        if let range = sentence.range(of: "note:", options: .caseInsensitive) { result.notes = String(sentence[range.upperBound...].trimmingCharacters(in: .whitespaces).prefix(500)) }
        return result
    }
}

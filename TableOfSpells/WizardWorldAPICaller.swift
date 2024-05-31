//
//  WizardWorldAPICaller.swift
//  TableOfSpells
//
//  Created by Daniel Bolella on 5/28/24.
//

import Foundation

struct Spell: Codable, Identifiable, Hashable {
    let id, name, effect, type, light: String
    let canBeVerbal: Bool?
    let incantation, creator: String?
}

typealias Spells = [Spell]

class WizardWorldAPICaller {
    static func fetchSpells() async throws -> Spells {
        var fetchedData: Spells = []
        
        let url = URL(string: "https://wizard-world-api.herokuapp.com/Spells")
        let request = URLRequest(url: url!)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response.http, httpResponse.isSuccessful {
            fetchedData = try JSONDecoder().decode(Spells.self, from: data)
        }
        
        return fetchedData
    }
}

extension URLResponse {
    var http: HTTPURLResponse? {
        return self as? HTTPURLResponse
    }
}

extension HTTPURLResponse {
    var isSuccessful: Bool {
        return 200 ... 299 ~= statusCode
    }
}

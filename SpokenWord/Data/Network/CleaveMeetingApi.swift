//
//  CleaveMeetingApi.swift
//  SpokenWord
//
//  Created by 松浦裕久 on 2024/03/02.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation

class CleaveMeetingAPI {
    func postSpeechText(text: String) async throws -> CleaveMeetingEntity {
        let url = URL(string: "https://vocal-circle-387923.an.r.appspot.com/cleave_meeting")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        var json = [String: Any]()
        json["sentence"] = text
        let jsonObject = try JSONSerialization.data(withJSONObject: json, options: [])
        request.httpBody = jsonObject
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpStatus = response as? HTTPURLResponse else { throw ApiError.unknown }
        if httpStatus.statusCode == 200 || httpStatus.statusCode == 201 {
            do {
                return try JSONDecoder().decode(CleaveMeetingEntity.self, from: data)
            } catch {
                throw ApiError.decodingError(error)
            }
        } else {
            throw ApiError.unknown
        }
    }
}

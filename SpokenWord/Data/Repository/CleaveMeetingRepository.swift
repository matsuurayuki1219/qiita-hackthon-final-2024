//
//  CleaveMeetingRepository.swift
//  SpokenWord
//
//  Created by 松浦裕久 on 2024/03/02.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation

class CleaveMeetingRepository {

    let api = CleaveMeetingAPI()

    func postSpeechMessage(text: String) async throws -> CleaveMeetingModel {
        return try await api.postSpeechText(text: text).toModel()
    }
}

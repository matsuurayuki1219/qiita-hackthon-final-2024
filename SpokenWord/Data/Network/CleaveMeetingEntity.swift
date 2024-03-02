//
//  CleaveMeetingEntity.swift
//  SpokenWord
//
//  Created by 松浦裕久 on 2024/03/02.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation

struct CleaveMeetingEntity: Codable {
    let id: Int
    let sentence: String
    let cleave: Bool
    let reason: String
}

extension CleaveMeetingEntity {
    func toModel() -> CleaveMeetingModel {
        return CleaveMeetingModel(
            id: id,
            sentence: sentence,
            cleave: cleave,
            reason: reason
        )
    }
}

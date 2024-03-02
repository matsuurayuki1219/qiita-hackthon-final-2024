//
//  CleaveMeetingEntity.swift
//  QiitaHackthonFinal2024
//
//  Created by 松浦裕久 on 2024/03/02.
//

import Foundation

struct CleaveMeetingEntity: Codable {
    let id: Int
    let sentence: String
    let cleave: Bool
}

extension CleaveMeetingEntity {
    func toModel() -> CleaveMeetingModel {
        return CleaveMeetingModel(
            id: id,
            sentence: sentence,
            cleave: cleave
        )
    }
}

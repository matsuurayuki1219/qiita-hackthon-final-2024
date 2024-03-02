//
//  CleaveMeetingRepository.swift
//  QiitaHackthonFinal2024
//
//  Created by 松浦裕久 on 2024/03/02.
//

import Foundation

protocol CleaveMeetingRepositoryProtocol {
    func postSpeechText(text: String) async throws -> CleaveMeetingModel
}

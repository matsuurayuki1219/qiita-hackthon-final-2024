//
//  ViewModel.swift
//  SpokenWord
//
//  Created by HONG JEONGSEOB on 2024/03/02.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation
import Combine

@MainActor
class ViewModel {

    @Published var results: [CleaveMeetingModel] = []

    @Published var result: CleaveMeetingModel?
    private let repository = CleaveMeetingRepository()

    func postSpeechText(text: String) {
        Task {
            do {
                let convertedText =  text.replacingOccurrences(of: "。", with: "→").replacingOccurrences(of: "？", with: "→")
                result = try await repository.postSpeechMessage(text: convertedText)
            } catch {
                print("サーバとの通信ができていません")
            }
        }
    }

    func splitText(_ text: String) -> [String] {
        return text.components(separatedBy: CharacterSet(charactersIn: "？。"))
    }
}

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
                
                let texts = splitText(text)
                for text in texts {
                    guard !text.isEmpty else { continue }
                    print("送りました！：\(text)")
                    let response = try await repository.postSpeechMessage(text: text)
                    result = response
                }
            } catch {
                // no-ops
                print("サーバとの通信ができていません")
            }
        }
    }

    func splitText(_ text: String) -> [String] {
//        return text.components(separatedBy: "。")
        return text.components(separatedBy: CharacterSet(charactersIn: "？。"))
    }
}

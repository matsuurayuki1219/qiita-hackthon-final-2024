//
//  ViewModel.swift
//  SpokenWord
//
//  Created by HONG JEONGSEOB on 2024/03/02.
//  Copyright © 2024 Apple. All rights reserved.
//

import Combine

@MainActor
class ViewModel {

    @Published var results: [CleaveMeetingModel] = []

    private let repository = CleaveMeetingRepository()

    func postSpeechText(text: String) {
        Task {
            do {
                let response = try await repository.postSpeechMessage(text: text)
                print(text)
                results.append(response)
            } catch {
                // no-ops
                // print("サーバとの通信ができていません")
            }
        }
    }
}

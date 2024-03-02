//
//  ApiError.swift
//  SpokenWord
//
//  Created by 松浦裕久 on 2024/03/02.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation

enum ApiError: Error {
    case decodingError(Error)
    case unknown
}

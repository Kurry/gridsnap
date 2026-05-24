//
//  DispatchTimeExtension.swift
//  GridSnap
//
//  Copyright © 2026 Kurry Tran. All rights reserved.
//

import Foundation

extension DispatchTime {
    var uptimeMilliseconds: UInt64 { uptimeNanoseconds / 1_000_000 }
}

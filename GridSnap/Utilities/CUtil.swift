//
//  CUtil.swift
//  GridSnap
//
//  Created by Kurry Tran on 6/12/19.
//  Copyright © 2026 Kurry Tran. All rights reserved.
//

import Foundation

class CUtil {
    
    // bridge object into a pointer to pass into C function
    static func bridge<T : AnyObject>(obj : T) -> UnsafeMutableRawPointer {
        return UnsafeMutableRawPointer(Unmanaged.passUnretained(obj).toOpaque())
    }
    
    // bridge pointer back into an object within C function
    static func bridge<T : AnyObject>(ptr : UnsafeMutableRawPointer) -> T {
        return Unmanaged<T>.fromOpaque(ptr).takeUnretainedValue()
    }
    
}

//
//  Weak.swift
//  SwiftX
//
//  Created by Patrik Karlsson on 2020-10-16.
//  Copyright © 2020 Patrik Karlsson. All rights reserved.
//

import Foundation

internal struct Weak<T> {
    private weak var _value: AnyObject?
    var value: T? {
        get { _value as? T }
        set { _value = newValue as AnyObject }
    }
    
    init(_ value: T) {
        self.value = value
    }
}

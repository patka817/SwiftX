//
//  MutexLock.swift
//  test
//
//  Created by Patrik Karlsson on 2020-10-02.
//  Copyright © 2020 Patrik Karlsson. All rights reserved.
//

import Foundation

final internal class MutexLock {
    enum MutexType: Int32 {
        case normal
        case recursive
    }
    
    private var _lock = pthread_mutex_t()
    
    init(type: MutexType = .normal) {
        var attr = pthread_mutexattr_t()
        guard pthread_mutexattr_init(&attr) == 0 else {
            preconditionFailure()
        }
        switch type {
        case .normal:
            pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_NORMAL)
        case .recursive:
            pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE)
        }
        guard pthread_mutex_init(&_lock, &attr) == 0 else {
            preconditionFailure()
        }
        pthread_mutexattr_destroy(&attr)
    }
    
    deinit {
        pthread_mutex_destroy(&self._lock)
    }
    
    final func inLock(_ work: () throws -> Void) rethrows {
        defer { unlock() }
        lock()
        try work()
    }
    
    final func inLock<ReturnType>(_ work: () throws -> ReturnType) rethrows -> ReturnType {
        defer { unlock() }
        lock()
        return try work()
    }
    
    final func tryLock() -> Bool {
        pthread_mutex_trylock(&_lock) == 0
    }
    
    final func lock() {
        pthread_mutex_lock(&_lock)
    }
    
    final func unlock() {
        pthread_mutex_unlock(&_lock)
    }
}

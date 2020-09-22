//
//  Mutex.swift
//  Longinus
//
//  Created by Qitao Yang on 2020/5/12.
//
//  Copyright (c) 2020 KittenYang <kittenyang@icloud.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Darwin

/** A pthread-based recursive mutex lock. */
public class Mutex {
    private var mutex: pthread_mutex_t = pthread_mutex_t()

    public init() {
        var attr: pthread_mutexattr_t = pthread_mutexattr_t()
        pthread_mutexattr_init(&attr)
        pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE)

        let err = pthread_mutex_init(&self.mutex, &attr)
        pthread_mutexattr_destroy(&attr)

        switch err {
        case 0:
            // Success
            break

        case EAGAIN:
            fatalError("Could not create mutex: EAGAIN (The system temporarily lacks the resources to create another mutex.)")

        case EINVAL:
                fatalError("Could not create mutex: invalid attributes")

        case ENOMEM:
            fatalError("Could not create mutex: no memory")

        default:
            fatalError("Could not create mutex, unspecified error \(err)")
        }
    }

    @discardableResult
    public final func lock() -> Int32 {
        let ret = pthread_mutex_lock(&self.mutex)
        switch ret {
        case 0:
            // Success
            break

        case EDEADLK:
            fatalError("Could not lock mutex: a deadlock would have occurred")

        case EINVAL:
            fatalError("Could not lock mutex: the mutex is invalid")

        default:
            fatalError("Could not lock mutex: unspecified error \(ret)")
        }
        return ret
    }

    @discardableResult
    public final func trylock() -> Int32 {
        let ret = pthread_mutex_trylock(&self.mutex)
        return ret
    }
    
    @discardableResult
    public final func unlock() -> Int32 {
        let ret = pthread_mutex_unlock(&self.mutex)
        switch ret {
        case 0:
            // Success
            break

        case EPERM:
            fatalError("Could not unlock mutex: thread does not hold this mutex")

        case EINVAL:
            fatalError("Could not unlock mutex: the mutex is invalid")

        default:
            fatalError("Could not unlock mutex: unspecified error \(ret)")
        }
        return ret
    }

    deinit {
        assert(pthread_mutex_trylock(&self.mutex) == 0 && pthread_mutex_unlock(&self.mutex) == 0, "deinitialization of a locked mutex results in undefined behavior!")
        pthread_mutex_destroy(&self.mutex)
    }

}

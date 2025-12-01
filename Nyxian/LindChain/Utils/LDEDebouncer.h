/*
 Copyright (C) 2025 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#ifndef LDEDEBOUNCER_H
#define LDEDEBOUNCER_H

#import <Foundation/Foundation.h>

@interface LDEDebouncer : NSObject

@property (nonatomic,assign,readwrite) NSTimeInterval delay;

- (instancetype)initWithDelay:(NSTimeInterval)delay withQueue:(dispatch_queue_t)queue;
- (instancetype)initWithDelay:(NSTimeInterval)delay withQueue:(dispatch_queue_t)queue withTarget:(id)target withSelector:(SEL)selector;

- (void)setTarget:(id)target withSelector:(SEL)selector;
- (void)debounce;

@end

#endif /* LDEDEBOUNCER_H */

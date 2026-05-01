/*
 * MIT License
 *
 * Copyright (c) 2024 light-tech
 * Copyright (c) 2026 cr4zyengineer
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#ifndef CCSOURCELOCATION_H
#define CCSOURCELOCATION_H

#include <CoreCompiler/CCBase.h>

typedef struct {
    Boolean isValid;
    CFIndex line, column;
} CCSourceLocation;

CC_EXPORT const CCSourceLocation CCSourceLocationZero;

CC_EXPORT CCSourceLocation CCSourceLocationMake(CFIndex line, CFIndex column);
CF_EXPORT Boolean CFSourceLocationIsValid(CCSourceLocation location);
CC_EXPORT Boolean CCSourceLocationEqualToLocation(CCSourceLocation location1, CCSourceLocation location2);

#endif /* CCSOURCELOCATION_H */

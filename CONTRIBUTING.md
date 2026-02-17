# Contributing to Nyxian

Thank you soooo much for your interest in Nyxian and contributing to it, I had the idea to make this file to show that im very confused about why nobody has contributed to Nyxian yet.

## Getting Started

### Prerequisites
- A mac with Xcode and Theos
- A iPhone/iPad with iOS 16+
- A free or paid apple developer account
- The certificate used to sign Nyxian (you can get that from keychain after installing nyxian over Xcode).

### Setup
1. Before you open Nyxian in Xcode **you have to run the Makefile first!**, otherwise you end up breaking project internal dependency configurations:

```bash
git clone --recursive https://github.com/ProjectNyxian/Nyxian.git
cd Nyxian
make jailed
```
2. Open it in Xcode (Now you can enjoyyy)

## Ways to contribute

### Good First Issues
You can find beginner friendly issues they are tagged with `good-first-issue`, they are beginner friendly.

### Documentation
Improvements to docs, examples, comments are always warmly welcomed.

### Bug Reports
Open an issue with:
- What you expected
- What happened
- Steps to reproduce
- Your environment (OS, version, etc)

### Feature Requests
Open an issue describing the use case before writing code.

## Submiting changes

1. Fork the repo
2. Create a branch (`git checkout -b fix/thing`)
3. Make your change
4. Run tests
5. Commit with clear message
6. Push and open a PR

## Code Style

### Swift
```swift
// Use [weak self] + guard in closures
someAsyncThing { [weak self] result in
    guard let self = self else { return }
    self.doThing(result)
}

// Inline closures for computed values
let key = {
    switch type {
    case .app: return "applications"
    case .utility: return "utilities"
    default: return "unknown"
    }
}()

// Use self. prefix
self.tableView.reloadData()

// K&R braces
func doThing() {
    // ...
}
```

### C / ObjC
```objc
/* Allman braces for functions */
void do_thing(int arg)
{
    /* comment style */
    
    /* null check before use */
  	/* there is no space between if and brace in my code! */
    if(ptr == NULL)
    {
        return;
    }
    
    /* lock/unlock clearly commented and the reason */
    os_unfair_lock_lock(&lock);
    
    /* operation here */
    
    os_unfair_lock_unlock(&lock);
}

/* snake_case for C functions */
TaskPortObject *get_tpo_for_pid(pid_t pid);
```

### General
- GPL v3 header on all new files
- Minimal comments - code should be self-documenting
- Defensive programming - check validity before operations (otherwise I will never ever again accept a PR from you)
- No force unwraps in Swift unless provably safe

## License Header
All files must include:
```
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
```
You have to add your name undernethe the names of other people that have contributed in-case youre not in that list already. If you're the original creator of a new file in Nyxian then your name is the first instead of mine, I add mine underneath yours in that case when I add or change something of your code!

## Questions?
Open an issue. Please search existing issues first.

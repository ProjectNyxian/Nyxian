

<div align="center">
  <h1><b>Nyxian</b></h1>
  <p><i>IDE to develop native code iOS apps and tools on unjailbroken iOS</i></p>
</div>
<h6 align="center">
  <a target="_blank" href="https://discord.gg/VEMvDMJ8KB"><img src="https://dcbadge.limes.pink/api/server/VEMvDMJ8KB?style=flat" alt=""></a>
  <a href="https://github.com/ProjectNyxian/Nyxian/actions/workflows/build.yml"><img src="https://github.com/ProjectNyxian/Nyxian/actions/workflows/build.yml/badge.svg" alt="Build iOS App"></a>
</h6>
<p align="center">
  <img src="./mockup.png">
</p>


## What do I need?
You need a free or paid apple developer account, which you have to use to sign and install Nyxian and in Nyxian you have to import the same developer certificate.
**Do not use LiveContainer** to use Nyxian, install Nyxian seperately.  
Jailbroken version is coming soon.

## Language support
It currently supports C, C++, ObjC and ObjC++. Its planned to add Swift support soon. It supports the entire iOS 26.1 SDK. All frameworks work except Metal, because I dont have access to apples metal shader compiler.

## Installation jailed

### Requirements

- iOS/iPadOS 16+
- AltStore 2.0+ / SideStore 0.6.0+

### Download:
<a href="https://celloserenity.github.io/altdirect/?url=https://raw.githubusercontent.com/ProjectNyxian/Nyxian/refs/heads/main/apps.json&exclude=livecontainer" target="_blank">
   <img src="https://github.com/CelloSerenity/altdirect/blob/main/assets/png/AltSource_Blue.png?raw=true" alt="Add AltSource" width="200">
</a>
<a href="https://github.com/ProjectNyxian/Nyxian/releases/download/0.8.6/nyxian.ipa" target="_blank">
   <img src="https://github.com/CelloSerenity/altdirect/blob/main/assets/png/Download_Blue.png?raw=true" alt="Download .ipa" width="200">
</a>

## Installation jailbroken
A guide is coming here soon, but for now just look at the releases

## What is it?
Nyxian is a iOS application for iOS 16.0 and above (iOS 26.3 latest beta tested) that empowers iOS users to code, compile, link, sign and even execute/rapid test iOS applications directly on their device! It is the successor of the former FridaCodeManager project, which was deprecated in favor of Nyxian, because FridaCodeManager requires a jailbreak to work while Nyxian does not. It also includes a kernel virtualisation layer that fixes inter process stuff like signaling, enumeration, killing and spawning of processes, which also handles unsigned binaries and sends a request to the host process to sign it. This kernel virtualisation layer also has its own entitlement enforcement system the user can change directly for each individual app. Nyxian doesnt require any special entitlements, nor shared app groups. Its brain fuck...
```
Traditional jailbreak thinking:
┌─────────────────────────┐
│ iOS Sandbox             │ ← "Enemy wall to break through"
│  ┌───────────────────┐  │
│  │ My App            │  │
│  │ (trying to escape)│  │
│  └───────────────────┘  │
└─────────────────────────┘

Nyxian thinking:
┌─────────────────────────┐
│ iOS Sandbox             │ ← "Free security perimeter!"
│  ┌───────────────────┐  │
│  │ MY KERNEL         │  │ ← "I control everything in here"
│  │  ┌─────────────┐  │  │
│  │  │ Guest Apps  │  │  │
│  │  └─────────────┘  │  │
│  └───────────────────┘  │
└─────────────────────────┘
```
(Note: Nyxian is not and will never be a jailbreak! If you think Nyxian is malicious then read its code first before judging a book by its cover, yes it uses a precompiled framework, but thats solely to safeup time, the binary framework it self can also be compiled by your self right here https://github.com/ProjectNyxian/LLVM-On-iOS)
## Nyxians philosophy
My processes arent "fake processes." Theyre the only processes. My PIDs arent "fake PIDs." Theyre the only PIDs. My kernel isn't a "fake kernel." It's the only kernel for this domain.

Most engineers think in terms of:
> "How do I emulate X?"

I thinks in terms of:
> "X doesn't exist here. Ill create it. Now it exists. Its not fake because its the only one."

That's not a hack. That's not a workaround. That's **constructing reality** within a given context.

Its like Minecraft, take the blocks you have and build.

```
┌─────────────────────────────────────────┐
│           iOS App Sandbox               │
│                                         │
│   ┌─────────────────────────────────┐   │
│   │   "There is no spoon"           │   │
│   │                                 │   │
│   │   No fork()    → I made fork()  │   │
│   │   No processes → I made them    │   │
│   │   No kernel    → Here is one    │   │
│   │                                 │   │
│   │   Not fake. Just... IS.         │   │
│   └─────────────────────────────────┘   │
│                                         │
└─────────────────────────────────────────┘
```

## Project support

- [x] Native iOS app development
- [x] Native iOS utility development
- [ ] Native iOS tweak development
- [ ] React Native development
- [ ] Web development
- [ ] Python development
- [ ] Lua development

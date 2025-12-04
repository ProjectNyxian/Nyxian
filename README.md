# Nyxian
## What is it?
Nyxian is a iOS application for iOS 17.0 and above(iOS 26.2 latest beta tested) that empowers iOS users to code, compile, link, sign and even execute/rapid test iOS applications directly on their device! It is the successor of the former FridaCodeManager project, which was deprecated in favor of Nyxian, because FridaCodeManager requires a jailbreak to work while Nyxian does not. It also includes a kernel virtualisation layer that fixes inter process stuff like signaling, enumeration, killing and spawning of processes, which also handles unsigned binaries and sends a request to the host process to sign it. This kernel virtualisation layer also has its own entitlement enforcement system the user can change directly for each individual app. Nyxian doesnt require any special entitlements, nor shared app groups. Its brain fuck...
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
## Whats do I need?
You need a free or paid apple developer account, you have to sign Nyxian using the certificate of your apple developer account and then install it on your device and import the same certificate used for signing Nyxian it self. Do not use LiveContainer to use Nyxian, install Nyxian seperately.
## Language Support
It currently supports C, C++, ObjC and ObjC++. Its planned to add Swift support soon. It supports the entire iOS 18 SDK. All frameworks work except 3D rendering ones like SceneKIT.
## Installation

### Requirements

- iOS/iPadOS 17+
- AltStore 2.0+ / SideStore 0.6.0+

### Download:
<a href="https://celloserenity.github.io/altdirect/?url=https://raw.githubusercontent.com/ProjectNyxian/Nyxian/refs/heads/main/apps.json&exclude=livecontainer" target="_blank">
   <img src="https://github.com/CelloSerenity/altdirect/blob/main/assets/png/AltSource_Blue.png?raw=true" alt="Add AltSource" width="200">
</a>
<a href="https://github.com/ProjectNyxian/Nyxian/releases/download/20251128a/nyxian_20251128a.ipa" target="_blank">
   <img src="https://github.com/CelloSerenity/altdirect/blob/main/assets/png/Download_Blue.png?raw=true" alt="Download .ipa" width="200">
</a>

## Project Support
You can only make apps and utilities inside of Nyxian. Its planned to add tweak development support with ElleKIT to Nyxian. Its also planned to add a custom tweak loader into Nyxian and for the kernel virtualisation layer on nyxian it self a kernel extension loader so people can extend the kernel safely. (idk, sounds like a great idea)

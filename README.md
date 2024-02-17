### A simple, stable user identifier across devices

[![SwiftPM compatible](https://img.shields.io/badge/SwiftPM-compatible-orange.svg)](#Installation)


StableID is a simple package that helps you keep a stable user identifier across devices by leveraging [iCloud Key Value Store](https://developer.apple.com/documentation/foundation/nsubiquitouskeyvaluestore)).

It's useful for services like [RevenueCat](https://github.com/RevenueCat/purchases-ios), where you may want to maintain a consistent user identifier to allow users to access their purchases across their devices, but you _don't_ want to have a complete account system or use anonymous identifiers.

StableID persists across all devices of a user's iCloud account.

## Installation

Add this repository as a Swift package.

```plaintext
https://github.com/codykerns/StableID
```

## Before using StableID

In order to use StableID, you'll need to add the iCloud capability to your target and enable `Key-value storage`:

<img width="692" alt="Screenshot 2024-02-17 at 1 12 04 AM" src="https://github.com/codykerns/StableID/assets/44073103/84adbea2-b27a-492d-b752-2b9f1b9d064d">

## Configuration

Initialize StableID:

```swift
StableID.configure()
```

By default, StableID will look for any other StableID identifier in iCloud or local user defaults - otherwise, it will generate a new identifier.

If you want to provide a custom identifier to force the client to be set to a specific identifier and update iCloud:

```swift
StableID.configure(id: <optional_user_id>)
```

Call `StableID.isConfigured` to see if StableID has already been configured.

### Changing identifiers

To change identifiers, call:

```swift
StableID.identify(id: <new_user_identifier>)
```

### Receiving updates

To receive updates when a user ID changes (for example from detecting a change from another iCloud device), configure a delegate:

```swift
StableID.set(delegate: MyClass())

class MyClass: StableIDDelegate {
    func willChangeID(currentID: String, candidateID: String) -> String? {
        // called before StableID changes IDs, it gives you the option to return the proper ID
    }
    
    func didChangeID(newID: String) {
        // called once the ID changes
    }
}
```

## License

MIT

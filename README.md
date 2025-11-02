### A simple, stable user identifier across devices

[![SwiftPM compatible](https://img.shields.io/badge/SwiftPM-compatible-orange.svg)](#Installation)

StableID is a simple package that helps you keep a stable user identifier across devices by leveraging [iCloud Key Value Store](https://developer.apple.com/documentation/foundation/nsubiquitouskeyvaluestore)).

It's useful for services like [RevenueCat](https://github.com/RevenueCat/purchases-ios), where you may want to maintain a consistent user identifier to allow users to access their purchases across their devices, but you _don't_ want to have a complete account system or use anonymous identifiers.

StableID persists across all devices of a user's iCloud account.

## 📦 Installation

Add this repository as a Swift package.

```plaintext
https://github.com/codykerns/StableID
```

## ℹ️ Before using StableID

In order to use StableID, you'll need to add the iCloud capability to your target and enable `Key-value storage`:

<img width="692" alt="Screenshot 2024-02-17 at 1 12 04 AM" src="https://github.com/codykerns/StableID/assets/44073103/84adbea2-b27a-492d-b752-2b9f1b9d064d">

## 🤩 The pitch: a single point to get a consistent ID

Getting the current stable identifier is simple:

```swift
let currentID = StableID.id
```

That's it. One line to get a user identifier that persists across devices and app reinstalls.

## 🛠️ Configuration

### Recommended: Use App Store Transaction ID (iOS 16.0+)

For App Store apps, the best way to configure StableID is using the App Store's AppTransactionID. This provides a globally unique, stable identifier tied to each user's Apple Account:

```swift
// Only fetch if not already configured
if StableID.hasStoredID {
    StableID.configure()
} else {
    Task {
        let id = try await StableID.fetchAppTransactionID()
        StableID.configure(id: id)
    }
}
```

Or, use a policy:
```swift
Task {
    let id = try await StableID.fetchAppTransactionID()
    StableID.configure(id: id, policy: .preferStored)
}
```

The `.preferStored` policy ensures that if an ID is already stored (from another device via iCloud), it will be used instead of the provided ID during the configure call. This keeps your ID consistent across all devices.

**Benefits:**
- Globally unique per Apple Account
- Persists across redownloads, refunds, and repurchases
- Works even without in-app purchases
- Unique per family member for Family Sharing apps
- Most reliable identifier for App Store distributed apps
- Only fetches from App Store once, then uses stored value

### Basic Configuration

Alternatively, you can initialize StableID with auto-generated identifiers:

```swift
StableID.configure()
```

By default, StableID will look for any other StableID identifier in iCloud or local user defaults - otherwise, it will generate a new identifier.

If you want to provide a custom identifier to force the client to be set to a specific identifier and update iCloud:

```swift
StableID.configure(id: <optional_user_id>)
```
    
Call `StableID.isConfigured` to see if StableID has already been configured.

### ID Policies

When providing an ID to `configure()`, you can specify a policy to control how that ID is used:

**`.preferStored`**
- Checks iCloud and local storage first
- Only uses the provided ID if no stored ID exists
- Ensures consistency across app launches

```swift
let id = try await StableID.fetchAppTransactionID()
StableID.configure(id: id, policy: .preferStored)
```

**`.forceUpdate`** (Default)
- Always uses the provided ID
- Updates storage with the new ID
- Use when you want to override any existing stored ID

```swift
StableID.configure(id: "user-123", policy: .forceUpdate)
```

### Changing identifiers

To change identifiers, call:

```swift
StableID.identify(id: <new_user_identifier>)
```

### Receiving updates

To receive updates when a user identifier changes (for example from detecting a change from another iCloud device), configure a delegate:

```swift
// call after configuring StableID
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

### Custom ID Generators

By default, StableID uses a standard `IDGenerator` that generates simple UUIDs.

If you want any generated identifiers to follow a certain pattern, you can implement a custom ID generator by conforming to `IDGenerator` and implementing `generateID()`:

```swift
struct MyCustomIDGenerator: IDGenerator {
    func generateID() -> String {
        // do something custom
        return myGeneratedID
    }
}
```

Then pass the generator as part of the `configure` method:

```swift
StableID.configure(idGenerator: MyCustomIDGenerator())
```

**Built-in generators**
- `StableID.StandardGenerator`: Standard UUIDs
- `StableID.ShortIDGenerator`: 8-character alphanumeric IDs

## 📚 Examples

<details>
<summary><b>Example 1: Basic Setup with RevenueCat</b></summary>

Configure StableID and use it to configure RevenueCat with a consistent user identifier:

```swift
import StableID
import RevenueCat

class AppDelegate: UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Configure StableID first
        if StableID.hasStoredID {
            StableID.configure()

            // Configure RevenueCat with StableID
            Purchases.configure(withAPIKey: "your_api_key", appUserID: StableID.id)
        } else {
            Task {
                // Try to fetch AppTransactionID, fallback to generated ID if it fails
                if let id = try? await StableID.fetchAppTransactionID() {
                    StableID.configure(id: id)
                } else {
                    StableID.configure()
                }

                // Configure RevenueCat after StableID is ready
                Purchases.configure(withAPIKey: "your_api_key", appUserID: StableID.id)
            }
        }

        return true
    }
}
```

</details>

<details>
<summary><b>Example 2: Handling ID Changes with RevenueCat</b></summary>

Use the delegate pattern to update RevenueCat when the StableID changes (e.g., from another device via iCloud):

```swift
import StableID
import RevenueCat

class AppCoordinator: StableIDDelegate {
    init() {
        // Set up StableID delegate
        StableID.set(delegate: self)
    }

    func willChangeID(currentID: String, candidateID: String) -> String? {
        // Optional: validate or modify the candidate ID
        return nil
    }

    func didChangeID(newID: String) {
        // Update RevenueCat with the new ID
        Purchases.shared.logIn(newID) { customerInfo, created, error in
            if let error = error {
                print("Error updating RevenueCat user: \(error)")
            } else {
                print("Successfully updated RevenueCat user to: \(newID)")
            }
        }
    }
}
```

</details>

<details>
<summary><b>Example 3: User Login Flow</b></summary>

Handle the case where a user logs into your app with their own account:

```swift
import StableID
import RevenueCat

func userDidLogin(userID: String) {
    // Update StableID to use the user's account ID
    StableID.identify(id: userID)

    // Update RevenueCat to match
    Purchases.shared.logIn(userID) { customerInfo, created, error in
        if let error = error {
            print("Error logging in to RevenueCat: \(error)")
        } else {
            print("Successfully logged in to RevenueCat")
        }
    }
}

func userDidLogout() {
    // Generate a new anonymous ID
    StableID.generateNewID()

    // Log out of RevenueCat and configure with new anonymous ID
    Purchases.shared.logOut { error in
        if let error = error {
            print("Error logging out of RevenueCat: \(error)")
        } else {
            Purchases.shared.logIn(StableID.id) { _, _, _ in
                print("Logged in to RevenueCat with new anonymous ID")
            }
        }
    }
}
```

</details>

<details>
<summary><b>Example 4: SwiftUI App with Async Configuration</b></summary>

For SwiftUI apps, configure StableID and RevenueCat in your App struct:

```swift
import SwiftUI
import StableID
import RevenueCat

@main
struct MyApp: App {
    @StateObject private var appCoordinator = AppCoordinator()

    init() {
        // Configure StableID with .preferStored policy
        Task {
            do {
                let id = try await StableID.fetchAppTransactionID()
                StableID.configure(id: id, policy: .preferStored)

                // Configure RevenueCat after StableID is ready
                Purchases.configure(withAPIKey: "your_api_key", appUserID: StableID.id)
            } catch {
                print("Error configuring StableID: \(error)")
                // Fallback to generated ID
                StableID.configure()
                Purchases.configure(withAPIKey: "your_api_key", appUserID: StableID.id)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appCoordinator)
        }
    }
}
```

</details>

<details>
<summary><b>Example 5: Custom ID Generator for Testing</b></summary>

Use a custom ID generator for testing or specific formatting requirements:

```swift
import StableID

struct TestIDGenerator: IDGenerator {
    func generateID() -> String {
        return "test-user-\(UUID().uuidString.prefix(8))"
    }
}

#if DEBUG
StableID.configure(idGenerator: TestIDGenerator())
#else
StableID.configure()
#endif
```

</details>

## 📙 License

MIT

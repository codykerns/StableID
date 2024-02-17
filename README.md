# A simple, stable user identifier across devices

StableID is a simple package that helps you keep a stable user identifier across devices by leveraging [iCloud Key Value Store](https://developer.apple.com/documentation/foundation/nsubiquitouskeyvaluestore)).

It's useful for services like RevenueCat, where you may want to maintain a consistent user identifier to allow users to access their purchases across their devices, but you _don't_ want to have a complete account system.


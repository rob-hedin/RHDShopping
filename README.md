# RHDShopping
Shopping Application

## Building

1. Clone [RHKrogerAPI](https://github.com/rob-hedin/RHKrogerAPI) next to this folder, so it sits at `../RHKrogerAPI`. The Xcode project references it by that relative path.
2. Copy `config/Secrets.example.xcconfig` to `config/Secrets.xcconfig` and fill in your Kroger client ID and secret. The file is git-ignored.
3. Open `RHDShopping.xcodeproj` and run the `RHDShopping` scheme (iOS 27). Without credentials the app opens to a "Couldn't start" message that says what's missing.

Run the unit tests with the same scheme (Product > Test). Location prompts only appear on a real device or with a simulated location set in the simulator.

# Vault Architecture

## Why the app is organized by feature

Vault is organized by feature so that each part of the product can own its own UI, state, and behavior.

This keeps changes local:

- authentication changes stay in authentication
- collection changes stay in collections
- file detail changes stay in file detail

It also helps avoid a large shared layer too early. The app is still growing, so it is better to keep ownership clear before extracting general-purpose code.

## App root files

### AppScreen.swift

`AppScreen.swift` is the root SwiftUI entry view for the app experience.

It decides whether the user should see:

- the unlock screen
- or the main navigation stack

It also owns the top-level route mapping from `AppRoute` values to feature screens.

### AppState.swift

`AppState.swift` owns only app-level coordination.

It is responsible for:

- whether the vault is locked or unlocked
- authentication progress
- route navigation state
- app lifecycle lock behavior
- preview coordination that must survive across screens

It should not become a dumping ground for screen-specific state.

### AppRoute.swift

`AppRoute.swift` defines the navigation destinations used by the app-level navigation stack.

It is the shared route contract between the root app flow and feature screens.

## Feature ownership

### Authentication

The authentication feature owns:

- the unlock screen UI
- unlock screen state
- device authentication behavior

### Home

The home feature owns:

- the home screen UI
- home screen state
- home-specific import and summary behavior

### Collections

The collections feature owns:

- the collections list UI
- collection detail UI
- collection-related state
- collection-related business operations

### FileDetail

The file detail feature owns:

- file detail UI
- file preview and file action state
- file access operations needed by that feature

## Service ownership

Services live inside the feature that owns the behavior.

That means:

- authentication services belong to the authentication feature
- collection services belong to the collections feature
- file detail services belong to the file detail feature

This keeps ownership clear and avoids creating global service folders too early.

## Avoid moving shared-looking logic too early

Some logic can look reusable before the app structure is mature.

We do not want to move code into global folders just because two screens use something similar once or twice. Shared code should be extracted only when the ownership and reuse are stable and obvious.

## DesignSystem

`DesignSystem` is reserved for future reusable design primitives that come from the product design work in `design.pen`.

For now it should stay small and intentional.

## Swift packages

The app uses two local Swift packages:

- `VaultSecurity`
- `VaultStorage`

`VaultSecurity` provides encryption and authentication-related infrastructure.

`VaultStorage` provides storage models and file import/storage operations.

Features use these packages through their own feature state and feature services. The packages are shared infrastructure, but feature behavior should still stay feature-owned inside the app target.

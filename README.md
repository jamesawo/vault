# Vault

Vault is a local-first iOS app for securely storing personal files on device.

The project is being built as a product repo, not just an Xcode app folder. It includes the app, the share extension, reusable Swift packages, design files, and visual artifacts used during development.

## What We Are Building

Vault is focused on a few core ideas:

- keep files stored locally
- protect access with device authentication
- encrypt file contents at rest
- make import, preview, and sharing flows feel simple
- keep the codebase modular enough to evolve cleanly

## Repo Structure

- `Vault/`
  The main iOS app target and SwiftUI screens.
- `VaultShareExtension/`
  Share extension for importing files from other apps.
- `Vault.xcodeproj/`
  Xcode project for the app and extension.
- `Packages/`
  Local Swift packages used by the app.
- `Config/`
  Project configuration files such as extension plist data.
- `Design/`
  Design source files that should evolve with the product.
- `Artifacts/`
  Screenshots and other visual artifacts captured during development and review.

## Packages

- `VaultSecurity`
  Authentication, key management, and encryption-related code.
- `VaultStorage`
  Storage models, import logic, and encrypted file persistence.

## Current Architecture

The app is built with SwiftUI and uses a simple layered structure:

- app-level state coordinates locking, unlocking, navigation, and preview state
- feature screens own their local UI state
- shared package code handles storage, import, encryption, and authentication

The share extension reuses the same storage and import pipeline as the main app.

## Development Notes

- the repo is intended to track app code, packages, design files, and review artifacts together
- local machine state and personal notes should stay ignored

## Status

Early product development. The main flows are being built and refined, and the repo structure is being set up to support ongoing feature work and review.

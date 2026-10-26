# ChargeNet mobile

Flutter driver application for simulated EV charging across three operators in
Malaysia, Singapore and Thailand. It provides station discovery, vehicles,
charging controls, live monitoring, wallet/history and settled receipts.

## Requirements and setup

Use Flutter stable with Dart satisfying `sdk: ^3.13.1` in `pubspec.yaml` (verified
with Flutter 3.47.1 / Dart 3.13.1). Start the companion `chargenet-backend` API on
port 8080 with its PostgreSQL service. Follow that repository's README for setup.

```sh
flutter pub get
flutter run
```

| Target | Default backend origin |
| --- | --- |
| Android emulator | http://10.0.2.2:8080 |
| iOS simulator, desktop, web | http://localhost:8080 |
| Physical device | Supply the development machine's reachable LAN address |

```sh
flutter run --dart-define=API_BASE_URL=http://192.168.1.3:8080
```

The app appends `/api/v1` to this origin. The device and host must share a network;
host firewall rules must allow port 8080. Development Android builds allow HTTP.
Use HTTPS and your own release-signing configuration before any public deployment.

## Demonstration

The backend seeds `demo@chargenet.my` / `Demo1234!`. These are public demonstration
credentials. Search for a station, choose a connector and vehicle, inspect the
estimated total and confirm charging. Estimates have no deadline. If the backend
detects changed pricing, review the new estimate and confirm again. Stop charging
to receive a final wallet payment and original-currency breakdown.

Selecting a search result dismisses the keyboard/results while retaining the map
jump and station details. Tapping the search field reopens results. Discovery
keeps one row of common filters and a sheet for country, region and power range.

## Verify and build

```sh
flutter analyze
flutter test --concurrency=1
flutter build apk --debug
```

Widget and service tests run with controlled data. Manual device testing covers
the complete driver-to-portal journey. Physical charger compatibility requires
separate testing. Platform builds need the corresponding SDK or toolchain.
Android local.properties and generated plugin/build files are excluded from Git.

See [architecture](docs/ARCHITECTURE.md).

## Development

ChargeNet uses rapid prototyping. Each increment starts on a short branch from
`main`, uses focused commits, and is merged with a merge commit after the relevant
checks pass. Shared increments use the same branch name in each repository they
change. Repositories unaffected by an increment receive no branch or commit.

## Attribution

Map data is © OpenStreetMap contributors. The map keeps this attribution visible
through its attribution control. The bundled Outfit font is Copyright 2021 The
Outfit Project Authors and is distributed under the SIL Open Font License 1.1.
The complete license is in `assets/fonts/OFL.txt`; the upstream project is
https://github.com/Outfitio/Outfit-Fonts.

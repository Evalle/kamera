<p align="center">
  <img src="Sources/Kamera/Assets.xcassets/AppIcon.appiconset/icon_256.png" width="128" height="128" alt="Kamera icon">
</p>

<h1 align="center">Kamera</h1>

<p align="center">
  <strong>A native macOS Kubernetes dashboard built with SwiftUI</strong>
</p>

<p align="center">
  <a href="#features">Features</a>&ensp;&bull;&ensp;
  <a href="#installation">Installation</a>&ensp;&bull;&ensp;
  <a href="#keyboard-shortcuts">Keyboard Shortcuts</a>&ensp;&bull;&ensp;
  <a href="#building-from-source">Building</a>&ensp;&bull;&ensp;
  <a href="#license">License</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014.4%2B-blue?style=flat-square" alt="macOS 14.4+">
  <img src="https://img.shields.io/badge/swift-6.0-orange?style=flat-square" alt="Swift 6.0">
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="MIT License">
</p>

---

Kamera connects directly to your Kubernetes clusters using your `~/.kube/config` &mdash; no proxy, no browser, no Electron. It reads cluster and auth configuration natively and talks to the K8s API over HTTPS with full TLS and exec-based credential support.

<p align="center">
  <img width="1013" height="587" alt="Screenshot 2026-02-20 at 14 23 29" src="https://github.com/user-attachments/assets/e44d2183-3c43-47b3-b99e-b6c00bc64141" />
</p>


## Features

- Tiny - only 4 MB vs hundreds on Electron-based analogs
- Super fast 
- Open-Source, MIT License

### 15 Resource Types

Browse all major Kubernetes resources organized into logical groups:

| Workloads | Config | Storage | Network | Cluster |
|-----------|--------|---------|---------|---------|
| Pods | ConfigMaps | PersistentVolumes | Services | Nodes |
| Deployments | Secrets | PersistentVolumeClaims | Ingresses | Events |
| StatefulSets | | | | |
| DaemonSets | | | | |
| ReplicaSets | | | | |
| Jobs | | | | |
| CronJobs | | | | |

### Cluster Health at a Glance

A status bar shows live counts of unready nodes, unhealthy pods, unavailable deployments, and failed jobs &mdash; all color-coded so problems are immediately visible.

### Custom Kubeconfig Path

Open **Settings** (`Cmd + ,`) to pick a kubeconfig file from any location. The choice is persisted across launches. Reset to default to fall back to `~/.kube/config` (or `$KUBECONFIG`).

<p align="center">
  <img width="496" height="446" alt="Screenshot 2026-02-20 at 14 24 44" src="https://github.com/user-attachments/assets/6028f7fe-dd55-4874-905a-60234801b626" />
</p>

### Multi-Cluster & Namespace Switching

Switch between contexts and namespaces from the sidebar. Supports **All Namespaces** mode to view resources across the entire cluster.

### Quick Search

Press **Cmd+K** to open a Spotlight-style search that finds resources by name across all types instantly.

<p align="center">
  <img width="478" height="379" alt="Screenshot 2026-02-20 at 14 25 49" src="https://github.com/user-attachments/assets/d1b01b91-973e-453d-b7c0-5aa910553485" />
</p>

### Live Pod Logs

Stream logs from any container in real-time with search filtering and auto-scroll.

<p align="center">
  <img width="604" height="660" alt="Screenshot 2026-02-20 at 14 26 35" src="https://github.com/user-attachments/assets/da4903fd-0baf-4030-b19b-e6b09e28d3a2" />
</p>

### YAML Inspector

View the full YAML/JSON definition of any resource with syntax highlighting and in-document search.

<p align="center">
  <img width="447" height="624" alt="Screenshot 2026-02-20 at 14 27 08" src="https://github.com/user-attachments/assets/46c09cd6-99e5-4116-af5c-79faaaaa1f4e" />
</p>

### Related Resource Trees

Drill into any Deployment, StatefulSet, DaemonSet, Job, CronJob, or Node to see its child resources as an expandable tree (e.g. Deployment &rarr; ReplicaSets &rarr; Pods).

<p align="center">
  <img width="300" height="631" alt="Screenshot 2026-02-20 at 14 28 08" src="https://github.com/user-attachments/assets/20cb8efe-d777-445e-bb9c-1b64694d2e1e" />
</p>


### Sortable Tables

Click any column header to sort resource lists. Filter with the built-in search bar per resource view.

### Auto-Refresh

Configurable auto-refresh at 2s, 15s, 30s, or 60s intervals (default: 2s) to keep data current without manual action.

<p align="center">
  <img width="221" height="137" alt="Screenshot 2026-02-20 at 14 28 30" src="https://github.com/user-attachments/assets/9d432e8a-a728-42f4-a43d-1b3420e6f4dd" />
</p>

### Authentication

- Bearer token
- Client certificate (TLS mutual auth)
- Exec-based credentials (e.g. `aws eks get-token`)
- auth-provider (GKE gcp, OIDC)

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd + ,` | Open Settings |
| `Cmd + R` | Refresh resources |
| `Cmd + K` | Quick search |
| `Cmd + Up` | Previous resource kind |
| `Cmd + Down` | Next resource kind |

## Installation

### Download

Grab the latest `Kamera.dmg` from the [Releases](../../releases) page, open it, and drag **Kamera.app** into **Applications**.

> **Note:** The app is not signed or notarized, so macOS will block it from running by default.
>
> To fix this, open a terminal and run:
> ```bash
> xattr -dr com.apple.quarantine /Applications/Kamera.app
> ```
> After this the app will launch normally.


This builds a Release `.app` and packages it into `build/Kamera.dmg`. You can also open `Kamera.xcodeproj` in Xcode and hit Run.

### Prerequisites

- A valid `~/.kube/config` with at least one context configured
- Network access to your Kubernetes API server

## Building from Source

```bash
# Generate Xcode project (uses XcodeGen)
make generate

# Debug build
make build

# Release build
make release

# Package as .dmg
make dmg

# Run tests
make test

# Or use Swift Package Manager directly
swift build
swift test
```

## License

[MIT](LICENSE)

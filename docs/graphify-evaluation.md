# Graphify evaluation for Karipa

Reviewed 2026-10-10. Recommendation: adopt neither tool for Phase 0 or the proposed initial design-system work. Nothing was installed, indexed, configured, or uploaded.

## Codebase knowledge graph

Identity evaluated: [Graphify-Labs/graphify](https://github.com/Graphify-Labs/graphify), distributed as the Python package `graphifyy`. Other forks exist; confirm this is the intended product before a future trial.

Its current documentation lists Dart among its tree-sitter languages, Codex integration through skill/instruction configuration, optional MCP, and Python 3.10+. It describes code extraction as local and deterministic; semantic processing of documents/media can use an assistant or configured model provider. Its Codex setup can modify `AGENTS.md` and tool configuration. The repository is not archived and includes tests and release documentation. These are publisher statements and repository observations, not a tested integration in PathCraft. [Maintainer README](https://github.com/Graphify-Labs/graphify#readme).

| Consideration | Assessment for this repository |
| --- | --- |
| Flutter/Dart usefulness | Dart syntax support is useful, but does not prove correct resolution of Provider state, named-route argument maps, Flutter widget composition, or dynamic callbacks. Those need a local correctness benchmark. |
| VS Code/Codex | Assistant-side tooling rather than a Flutter UI library. Setup adds instruction/configuration maintenance to the current lightweight workflow. |
| Maintenance/compatibility | Pin and review a version in any future pilot; broad assistant support does not establish compatibility with this installed environment. No installation test performed. |
| Privacy | A code-only local mode and an LLM-assisted document mode have different data boundaries. Audit exclusions and provider behavior before allowing private chapters, GPS fixtures, credentials, or generated indexes to be processed/shared. Local indexes can themselves contain sensitive excerpts. |
| Overhead | Developer-machine indexing/storage and possible model cost, not app binary/runtime overhead. Refreshing the graph after changes is extra work. |
| Current value | Seventeen screens, three services, two models, and explicit named navigation are tractable with repository search, Inspector, and the new frontend guide. There is no measured navigation/search bottleneck. |

**Optional later pilot:** only if repeated cross-file tracing becomes slow. Use a disposable checkout and an explicitly approved source-only scope. Benchmark five known questions (screen-to-service use, callers, route arguments, protected paths, shared-widget consumers) against manual inspection. Measure correctness, omissions, setup/index refresh time, and net task time. Adopt only if it improves the actual workflow without altering frontend instructions unexpectedly. No claim of measured speed or token savings is made here.

## Flutter charting package

Identity evaluated: [`graphify` on pub.dev](https://pub.dev/packages/graphify), maintained in [warioddly/graphify](https://github.com/warioddly/graphify).

The package page lists version 1.2.1 and describes an Apache ECharts bridge configured through chart options. Dependencies include `web` and `webview_flutter`. The maintainer repository was archived on **2026-05-09** and is read-only. [Package metadata](https://pub.dev/packages/graphify), [archived repository](https://github.com/warioddly/graphify).

| Consideration | Assessment for Karipa |
| --- | --- |
| Flutter/Dart | It is a Flutter library, but exact compatibility with Flutter 3.47.7/Dart 3.13.5 has not been tested. Package platform badges do not establish runtime support for our targets. |
| Editor integration | Ordinary package authoring/debugging in VS Code; no special Codex benefit. |
| Setup and maintenance | A new dependency plus WebView/JavaScript integration; archived upstream weakens the case for adoption. |
| Privacy | Review script/asset loading and network requests before supplying fitness data. No network/data-handling audit was performed, so offline/private behavior is not guaranteed. |
| Performance | Adds a web-rendering/JavaScript layer for charts, with potential memory/startup/accessibility costs. These costs have not been benchmarked on our devices. |
| Actual need | Current screens show metric tiles, route maps, and history cards. No approved chart requirement needs ECharts or 3D visualizations. |

**Not necessary for current scope.** Keep existing metric widgets and maps. If the capstone later requires charts, first define the data contract, accessible text equivalent, interaction requirements, and representative device performance budget. Evaluate actively maintained options at that time; do not select or install a replacement package in Phase 0.

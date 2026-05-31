# Spending Tracker

A personal macOS spending tracker built with SwiftUI and SwiftData, featuring an AI-powered chatbot that can read and modify your finances using natural language.

## Features

### Dashboard
An 8-widget dashboard showing your financial picture at a glance: monthly income/expense/net summary, 30-day spending trend chart, top categories breakdown, budget burn-down progress, payment method distribution, recent transactions, largest expense, and month-over-month category comparisons.

### Transactions
Full CRUD with a list view, inline row display, and an editor sheet. Each transaction records an amount in INR, type (expense/income), date, note, category, and payment method. Quick-add with ⌘N from anywhere.

### Advanced Search
Filter by text search, date range, transaction type, min/max amount, and multi-select category/payment-method chips. Results update in real time.

### Budget Tracking
Set per-category monthly budgets. Track progress with color-coded bars (green → orange → red). Flexible period picker supports this month, last month, a specific month, or a custom date range. Edit or delete budgets inline.

### AI Chatbot
Chat with your spending data in natural language via Ollama. The bot can:
- **Add, update, and delete transactions** ("Add ₹250 lunch paid by UPI")
- **Search and list transactions** ("Show my 5 biggest expenses this month")
- **View categories and payment methods** ("What categories do I have?")
- **Generate spending summaries** ("Break down my spending by category this month")
- **Check budget status** ("Am I on track with my budgets?")

Features include streaming responses, collapsible thinking/reasoning blocks, markdown rendering (tables, code blocks, lists), tool-call confirmation UI, and a compact one-line input with native spell-check and autocorrect.

### Category & Payment Method Management
Edit categories (name, color, SF Symbol icon) and payment methods (name, kind) through slide-in sheets with live previews. Archive items you no longer use without deleting them. Browse a curated library of 130+ SF Symbols organized by category.

### Import & Export
Back up all data (transactions, categories, payment methods, budgets, and optional chat history) as JSON. Two import modes: merge (upsert, deduplicate by name) or replace (wipe and restore).

## Tech Stack

| Component | Technology |
|-----------|------------|
| Language | Swift 6 (async/await, actors, Sendable) |
| UI | SwiftUI (NavigationSplitView, Charts, Forms) |
| Persistence | SwiftData |
| Charts | Swift Charts |
| Markdown | [swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui) 2.4.1 |
| LLM | [Ollama](https://ollama.com) HTTP API with tool calling |
| Testing | Swift Testing + XCTest |
| Minimum | macOS 15.0 (Sequoia) |

## Requirements

- macOS 15.0 or later
- Xcode 16+ (Swift 6 toolchain)
- [Ollama](https://ollama.com) running locally (required for chatbot features)

## Getting Started

### 1. Clone and open

```bash
git clone <repo-url>
cd "Spending Tracker"
open "Spending Tracker.xcodeproj"
```

### 2. Set up Ollama

Install Ollama and pull a model that supports tool calling:

```bash
brew install ollama
ollama serve
ollama pull llama3.1
```

For thinking/reasoning support, use a thinking-capable model:

```bash
ollama pull qwen3
```

### 3. Build and run

In Xcode, select the **Spending Tracker** scheme and **My Mac** as the destination, then press ⌘R.

Or from the command line:

```bash
xcodebuild -project "Spending Tracker.xcodeproj" \
  -scheme "Spending Tracker" \
  -destination 'platform=macOS' \
  build
```

The app auto-seeds 10 categories and 5 payment methods on first launch.

### 4. Configure the chatbot

Open **Settings → LLM** in the sidebar to configure the Ollama base URL (defaults to `http://localhost:11434`), model name, temperature, and per-tool-type permission policies (auto/confirm/disabled).

## Project Structure

```
Spending Tracker/
├── App/                   # DI container
├── Models/                # SwiftData @Model classes + domain enums
├── Persistence/           # ModelContainer, seeder, import/export
├── Repositories/          # Protocol-based CRUD per entity
├── LLM/
│   ├── Client/            # LLMClient protocol + Ollama implementation
│   ├── Tools/             # 11 tools (transactions, categories, reports)
│   └── Chat/              # ChatService (streaming + tool-call loop)
├── Features/
│   ├── Dashboard/         # Dashboard widgets (8 cards)
│   ├── Transactions/      # List, editor, row views
│   ├── Search/            # Advanced filter search
│   ├── Budgets/           # Budget management + range picker
│   ├── Chatbot/           # Chat UI + markdown + thinking + suggestions
│   ├── Settings/          # Categories, payment methods, LLM, backup
│   └── Sidebar/           # NavigationSplitView + routing
├── Utils/                 # Currency, dates, colors, JSON helpers
└── Assets.xcassets/       # App icon + accent color
```

## Architecture

- **MVVM** with `@Observable` view models and protocol-based repositories.
- **DI** via `AppContainer` — all dependencies wired at app start, testable with mock implementations.
- **SwiftData** for persistence — in-memory containers used in tests for isolation.
- **Tool system** — the chatbot registers tools as protocol-conforming objects. Each tool declares a name, description, JSON Schema parameters, and a `run` method. `ChatService` orchestrates the tool-call loop with a configurable iteration limit and per-tool-kind confirmation policy.
- **Thinking/reasoning** — thinking-capable Ollama models return reasoning in a separate `thinking` field, which the client folds into the message content as tagged blocks for the UI to render in a collapsible disclosure.

## Testing

```bash
xcodebuild test \
  -project "Spending Tracker.xcodeproj" \
  -scheme "Spending Tracker" \
  -destination 'platform=macOS' \
  -only-testing:"Spending TrackerTests"
```

Tests cover repositories (CRUD, queries, relationships), tools (add/list/delete/summary, validation, duplicate detection), chat service (plain text, tool-call loop with mock LLM client), and import/export (round-trip, merge, replace).

**Known issue**: Some async `@Test` cases involving SwiftData writes crash under Swift 6.2 / Xcode 26 beta. See `docs/KNOWN_ISSUES.md` for details and workarounds.

## Documentation

- `docs/ARCHITECTURE.md` — architecture overview, component walkthrough, and maintenance guide
- `docs/KNOWN_ISSUES.md` — known issues and workarounds

# Spending Tracker

A personal macOS spending tracker with an AI chatbot that reads and modifies your finances using natural language.

## Features

- **Dashboard** - income/expense summary, spending trends, top categories, budget progress, payment method distribution, recent transactions, largest expense, and month-over-month comparisons
- **Transactions** — full CRUD with list view, inline rows, and editor sheet.
- **Advanced Search** — filter by text, date range, type, amount, and category/payment-method chips
- **Budget Tracking** - per-category monthly budgets
- **AI Chatbot** - Currently Supports Ollama and Apple Intelligence. Add, update, delete transactions; search data; generate summaries - all in natural language (e.g., "Add ₹250 lunch paid by UPI"). Supports visual inputs, using LLM Vision capabilities, or using the macOS Vision API
- **Category & Payment Methods** - customize names, colors, icons; archive unused items
- **Backup & Restore** - JSON backup with merge or replace modes

## Tech Stack

Swift 6 · SwiftUI · SwiftData · Swift Charts · [swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui) 2.4.1 · Ollama HTTP API

## Requirements

- macOS 15.0+
- Xcode 16+ (Swift 6 toolchain)

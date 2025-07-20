# SwiftralinoWebView

Modern TypeScript/React frontend for Swiftralino with multi-runtime support.

## Features

- ⚛️ **React 18** with TypeScript
- 🎨 **Tailwind CSS** for styling
- 🔌 **WebSocket Bridge** for Swift backend communication
- 🌐 **Multi-runtime support**: Node.js, Deno, Bun
- 📦 **Vite** for fast development and building
- 🧪 **Vitest** for testing

## Quick Start

1. **Install dependencies**:
   ```bash
   # With Bun (recommended)
   cd Sources/SwiftralinoWebView
   bun install

   # Or with npm/yarn
   npm install
   # yarn install
   ```

2. **Development**:
   ```bash
   # Start development server
   bun run dev

   # Or with specific runtime
   bun run dev:node
   bun run dev:deno
   bun run dev:bun
   ```

3. **Build for production**:
   ```bash
   bun run build
   ```

## Architecture

- **`src/lib/swiftral-client.ts`**: WebSocket client for Swift backend
- **`src/lib/swiftral-context.tsx`**: React context provider
- **`src/types/swiftral.ts`**: TypeScript type definitions
- **`src/components/`**: React UI components
- **`vite.config.ts`**: Builds to `../../Public/` for Swift server

## Swift Backend Integration

The WebView communicates with the Swift backend via WebSocket at
`ws://127.0.0.1:8080/bridge`.

Available APIs:

- System information
- File system operations
- Process execution
- Real-time event handling

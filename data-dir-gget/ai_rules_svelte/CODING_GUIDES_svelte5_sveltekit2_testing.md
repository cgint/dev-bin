# Testing Guide for Svelte 5 & SvelteKit 2 - Comprehensive Best Practices

## Introduction to Testing Strategy

This guide outlines comprehensive testing practices for Svelte 5 and SvelteKit 2 projects, covering unit tests, integration tests, end-to-end testing, and test coverage. The strategy employs a multi-faceted approach combining different testing layers for robust application quality assurance.

## Testing Architecture & Tools

### Core Testing Stack

1. **Vitest**: Fast, modern testing framework for unit and integration tests (server-side API routes, services, stores, and isolated components)
2. **Playwright**: End-to-end (E2E) testing framework for simulating real user interactions and full application flows
3. **MSW (Mock Service Worker)**: Network-level HTTP request interception and mocking for reliable external API testing
4. **@vitest/coverage-v8**: Code coverage reporting to identify untested areas
5. **@testing-library/svelte**: Component testing utilities focused on user behavior rather than implementation details
6. **jsdom**: Browser environment simulation for Node.js testing

### Project Structure for Testing

Organize tests in a clear, maintainable structure:

```
tests/
├── api/          # Server-side tests for API endpoints (+server.ts files)
├── components/   # Client-side component tests (isolated UI logic)
├── e2e/          # End-to-end tests (full application flows with Playwright)
├── mocks/        # Centralized mock definitions
│   ├── api-handlers.ts    # MSW handlers for external APIs
│   ├── request-event.ts   # Helpers for mocking SvelteKit RequestEvent
│   ├── fixtures/          # Test data fixtures
│   └── services/          # Mock service implementations
├── services/     # Unit tests for backend service classes
├── stores/       # Unit tests for Svelte stores
└── setup.ts      # Global test setup (MSW server, global mocks)
```

## Dependency Injection for Testability

### Service Container Pattern

Implement a dependency injection system to enable easy mocking and service isolation:

**`src/lib/services/container.ts`**:
```typescript
export class ServiceContainer {
  private services = new Map<string, any>();
  
  register<T>(key: string, service: T): void { /* ... */ }
  get<T>(key: string): T { /* ... */ }
  override<T>(key: string, service: T): void { /* ... */ } // For test overrides
  
  static createProdContainer(): ServiceContainer { /* ... */ }
  static createTestContainer(overrides: Record<string, any> = {}): ServiceContainer { /* ... */ }
}
```

**`src/lib/services/index.ts`**:
```typescript
export const services = ServiceContainer.createProdContainer();
export function overrideServicesForTesting(overrides: Record<string, any>): void {
  Object.entries(overrides).forEach(([key, service]) => {
    services.override(key, service);
  });
}
```

This pattern allows production code to use real services while tests can inject mocked versions seamlessly.

## Mock Service Worker (MSW) Setup

### External API Mocking

MSW provides reliable, network-level mocking for external API calls:

**`src/tests/mocks/api-handlers.ts`**:
```typescript
import { http, HttpResponse } from 'msw';

export const handlers = [
  http.post('https://api.openai.com/v1/chat/completions', () => {
    return HttpResponse.json({
      choices: [{ message: { content: 'Mocked OpenAI response' } }],
      usage: { total_tokens: 100 }
    });
  }),
  http.post('https://api.anthropic.com/v1/messages', () => {
    return HttpResponse.json({
      content: [{ text: 'Mocked Anthropic response' }]
    });
  }),
  // Add handlers for all external APIs (Gemini, Perplexity, Tavily, etc.)
];
```

**`src/tests/setup.ts`**:
```typescript
import { beforeAll, afterEach, afterAll } from 'vitest';
import { setupServer } from 'msw/node';
import { handlers } from './mocks/api-handlers';

const server = setupServer(...handlers);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

## Testing Different Application Layers

### 1. API Route Testing (Server-Side)

Test SvelteKit API endpoints directly by importing and invoking their handler functions:

**`src/tests/api/chat.test.ts`**:
```typescript
import { describe, it, expect, beforeEach } from 'vitest';
import { POST } from '../../routes/api/chat/+server';
import { overrideServicesForTesting } from '$lib/services';
import type { ILlmProvider } from '$lib/services';
import { createMockRequestEvent } from '../mocks/request-event';

describe('/api/chat', () => {
  beforeEach(() => {
    overrideServicesForTesting({
      llmProvider: { generateAnswer: async () => 'Test LLM response' } as ILlmProvider,
    });
  });

  it('should handle basic chat request without search', async () => {
    const requestBody = { message: 'Hello', searchEnabled: false };
    const request = new Request('http://localhost/api/chat', {
      method: 'POST',
      body: JSON.stringify(requestBody),
      headers: { 'content-type': 'application/json' }
    });
    const requestEvent = createMockRequestEvent(request);
    
    const response = await POST(requestEvent);
    
    expect(response.status).toBe(200);
    const data = await response.json();
    expect(data.combined_search_result.answer).toBe('Test LLM response');
  });
});
```

### 2. Svelte Store Testing

Test stores that interact with browser APIs by mocking global objects:

**`src/tests/stores/chat.test.ts`**:
```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { get } from 'svelte/store';
import { chatSessions, currentSessionId } from '../../lib/stores/chat';

// Mock browser environment
vi.mock('$app/environment', () => ({ browser: false }));
vi.mock('../../lib/stores/toast', () => ({ toasts: { show: vi.fn() } }));

describe('Chat Store', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should add a new chat session', () => {
    const sessionId = chatSessions.addChatSession('First message');
    const sessions = get(chatSessions);
    expect(sessions).toHaveLength(1);
    expect(sessions[0].title).toBe('First message');
  });

  it('should set current session ID', () => {
    const sessionId = 'test-session-id';
    currentSessionId.set(sessionId);
    expect(get(currentSessionId)).toBe(sessionId);
  });
});
```

### 3. Service Layer Testing

Test business logic services in isolation:

**`src/tests/services/llm-provider.test.ts`**:
```typescript
import { describe, it, expect, beforeEach } from 'vitest';
import { LlmProvider } from '../../lib/services/adapters/llm-provider';
import type { IOpenAiService } from '../../lib/services/interfaces';

describe('LlmProvider', () => {
  let mockOpenAiService: IOpenAiService;
  let llmProvider: LlmProvider;

  beforeEach(() => {
    mockOpenAiService = {
      generateAnswer: vi.fn().mockResolvedValue('Generated response')
    };
    llmProvider = new LlmProvider(mockOpenAiService);
  });

  it('should generate answer using OpenAI service', async () => {
    const result = await llmProvider.generateAnswer('Test prompt');
    
    expect(mockOpenAiService.generateAnswer).toHaveBeenCalledWith('Test prompt');
    expect(result).toBe('Generated response');
  });
});
```

## End-to-End (E2E) Testing with Playwright

### Enhanced UI Testing Strategy

Build on the existing UI testing approach with improved practices:

### Test Case Organization

Structure E2E tests based on user flows and application features:

**`tests/e2e/chat-functionality.spec.ts`**:
```typescript
import { test, expect } from '@playwright/test';

test.describe('Chat Functionality', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('should send a message and receive response', async ({ page }) => {
    // Arrange: Navigate to chat interface
    await page.locator('[data-testid="chat-input"]').fill('Hello, how are you?');
    
    // Act: Send message
    await page.locator('[data-testid="send-button"]').click();
    
    // Assert: Verify message appears and response is received
    await expect(page.locator('[data-testid="user-message"]').last()).toContainText('Hello, how are you?');
    await expect(page.locator('[data-testid="ai-response"]').last()).toBeVisible();
  });

  test('should handle search-enabled chat requests', async ({ page }) => {
    await page.locator('[data-testid="search-toggle"]').check();
    await page.locator('[data-testid="chat-input"]').fill('What is the weather today?');
    await page.locator('[data-testid="send-button"]').click();
    
    await expect(page.locator('[data-testid="search-results"]')).toBeVisible();
    await expect(page.locator('[data-testid="ai-response"]').last()).toBeVisible();
  });
});
```

### API Key Handling in Tests

**Environment Variables (Recommended):**

1. **`.env.test` File**: Store test-specific API keys
2. **Separate Test Keys**: Use dedicated API keys for testing
3. **Secure Access**: Load via `process.env.API_KEY_NAME` in tests
4. **Git Exclusion**: Add `.env.test` to `.gitignore`

### Enhanced UI Test Stability

**1. Robust Selectors with `data-testid`:**
```typescript
// In Svelte components
<button data-testid="send-button" on:click={sendMessage}>Send</button>
<div data-testid="chat-messages" class="messages">
  {#each messages as message}
    <div data-testid="message-{message.id}" class="message">
      {message.content}
    </div>
  {/each}
</div>

// In Playwright tests
await page.locator('[data-testid="send-button"]').click();
await expect(page.locator('[data-testid="message-123"]')).toBeVisible();
```

**2. Advanced Page Object Model:**
```typescript
// tests/e2e/pages/chat-page.ts
export class ChatPage {
  constructor(private page: Page) {}

  async sendMessage(text: string) {
    await this.page.locator('[data-testid="chat-input"]').fill(text);
    await this.page.locator('[data-testid="send-button"]').click();
  }

  async waitForResponse() {
    await this.page.locator('[data-testid="ai-response"]').last().waitFor();
  }

  async getLastMessage() {
    return await this.page.locator('[data-testid="user-message"]').last().textContent();
  }
}
```

**3. Improved Synchronization:**
```typescript
// Wait for specific application states
await page.locator('[data-loading-state="complete"]').waitFor();
await page.waitForLoadState('networkidle');

// Custom state indicators
await page.locator('[data-api-response-received="true"]').waitFor();
```

## Code Coverage Configuration

### Vitest Coverage Setup

**`vitest.config.ts`**:
```typescript
import { defineConfig } from 'vitest/config';
import { sveltekit } from '@sveltejs/kit/vite';

export default defineConfig({
  plugins: [sveltekit()],
  test: {
    environment: 'jsdom', // or 'node' for server-side code
    setupFiles: ['./src/tests/setup.ts'],
    include: ['src/**/*.{test,spec}.{js,ts}'],
    globals: true,
    coverage: {
      provider: 'v8',
      include: ['src/**/*.{ts,js,svelte}'],
      exclude: [
        'src/tests/**',
        'src/**/*.d.ts',
        'src/app.html',
        '.svelte-kit/**',
        'static/**',
        'src/routes/**/+*.{js,ts}' // Exclude SvelteKit route files if desired
      ],
      reporter: ['text', 'html', 'lcov'],
      reportsDirectory: './coverage',
      thresholds: {
        lines: 80,
        functions: 75,
        branches: 70,
        statements: 80
      }
    }
  }
});
```

## Automated Testing Integration

### Pre-commit Hooks

**`package.json` scripts**:
```json
{
  "scripts": {
    "test": "vitest",
    "test:run": "vitest run",
    "test:coverage": "vitest run --coverage",
    "test:e2e": "playwright test",
    "test:all": "npm run test:run && npm run test:e2e",
    "precommit": "npm run test:run && sh precommit.sh"
  }
}
```

**`prec_plugin_npmtest.sh`**:
```bash
#!/bin/bash
echo "Running Vitest tests..."
npm run test:run

if [ -f "playwright.config.ts" ]; then
  echo "Installing Playwright dependencies..."
  npx playwright install --with-deps
fi
```

## Setup Instructions for New Projects

### 1. Install Dependencies
```bash
npm install -D vitest @vitest/coverage-v8 @testing-library/svelte @testing-library/jest-dom msw @playwright/test jsdom
npx playwright install --with-deps
```

### 2. Configure Test Environment
1. Copy `vitest.config.ts` and adjust paths/thresholds
2. Create `src/tests/setup.ts` with MSW server setup
3. Create `src/tests/mocks/api-handlers.ts` for external API mocks
4. Set up dependency injection with `ServiceContainer`

### 3. Add Test Scripts
Copy relevant test scripts to `package.json`

### 4. Integrate Pre-commit Hooks
Copy `precommit.sh` and test plugins, run setup

### 5. Start Writing Tests
Follow the patterns demonstrated in each testing layer:
- API routes: Direct function invocation with mocked services
- Stores: Mock browser environment and dependencies
- Services: Unit test with dependency injection
- Components: Use @testing-library/svelte
- E2E: Playwright with Page Object Model

## Component Testing Best Practices

### Testing Svelte Components

**`src/tests/components/chat-input.test.ts`**:
```typescript
import { render, screen, fireEvent } from '@testing-library/svelte';
import { vi } from 'vitest';
import ChatInput from '../../lib/components/chat/ChatInput.svelte';

describe('ChatInput', () => {
  it('should emit message on send button click', async () => {
    const mockSend = vi.fn();
    render(ChatInput, { onSend: mockSend });
    
    const input = screen.getByTestId('chat-input');
    const sendButton = screen.getByTestId('send-button');
    
    await fireEvent.input(input, { target: { value: 'Test message' } });
    await fireEvent.click(sendButton);
    
    expect(mockSend).toHaveBeenCalledWith('Test message');
  });

  it('should disable send button when input is empty', () => {
    render(ChatInput);
    
    const sendButton = screen.getByTestId('send-button');
    expect(sendButton).toBeDisabled();
  });
});
```

## Testing Application State & Instrumentation

### Adding Test-Friendly State Indicators

**In Svelte Components**:
```svelte
<script>
  let isLoading = false;
  let apiResponseReceived = false;
  
  async function handleSubmit() {
    isLoading = true;
    try {
      const response = await fetch('/api/chat', { /* ... */ });
      apiResponseReceived = true;
    } finally {
      isLoading = false;
    }
  }
</script>

<div 
  data-loading-state={isLoading ? 'loading' : 'complete'}
  data-api-response-received={apiResponseReceived}
>
  <!-- Component content -->
</div>
```

**Custom Events for Complex State Changes**:
```typescript
// Dispatch custom events for test synchronization
document.dispatchEvent(new CustomEvent('data-loaded', { detail: { type: 'chat-response' } }));

// In tests, listen for these events
await page.evaluate(() => {
  return new Promise((resolve) => {
    document.addEventListener('data-loaded', resolve, { once: true });
  });
});
```

This comprehensive testing approach ensures robust, maintainable, and reliable test coverage across all layers of your Svelte 5 and SvelteKit 2 application, from unit tests to full end-to-end user flows.
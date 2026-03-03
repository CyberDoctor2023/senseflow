# Langfuse OpenTelemetry Integration - Setup Guide

## Overview

This integration adds Langfuse tracing to SenseFlow using OpenTelemetry. All LLM calls, tool executions, and Smart AI recommendations will be automatically traced and sent to Langfuse for observability.

---

## Step 1: Add OpenTelemetry Swift Packages

Since the Swift Package Manager integration must be done manually in Xcode:

1. **Open SenseFlow.xcodeproj in Xcode**

2. **Add Package Dependencies**:
   - Go to **File → Add Package Dependencies...**
   - Enter the repository URL: `https://github.com/open-telemetry/opentelemetry-swift`
   - Select version: **Up to Next Major Version** starting from `1.0.0`
   - Click **Add Package**

3. **Select Package Products**:
   When prompted, add these three products to the **SenseFlow** target:
   - ✅ `OpenTelemetryApi`
   - ✅ `OpenTelemetrySdk`
   - ✅ `OpenTelemetryProtocolExporterHttp`

4. **Click Add** to complete the package installation

---

## Step 2: Configure Langfuse Credentials

### Option A: Environment Variables (Recommended)

Add your Langfuse API keys as environment variables in Xcode:

1. **Edit Scheme**:
   - In Xcode, go to **Product → Scheme → Edit Scheme...**
   - Select **Run** in the left sidebar
   - Go to the **Arguments** tab
   - Under **Environment Variables**, add:

   ```
   LANGFUSE_PUBLIC_KEY = pk-lf-your-public-key-here
   LANGFUSE_SECRET_KEY = sk-lf-your-secret-key-here
   ```

2. **Get Your API Keys**:
   - Sign up at [Langfuse Cloud](https://cloud.langfuse.com) (EU region)
   - Or use [US region](https://us.cloud.langfuse.com)
   - Or [self-host Langfuse](https://langfuse.com/self-hosting)
   - Navigate to **Project Settings → API Keys**
   - Copy your Public Key and Secret Key

### Option B: Hardcode in TracingService.swift (Not Recommended for Production)

If you prefer to hardcode the keys for testing:

1. Open `SenseFlow/Services/TracingService.swift`
2. Find the `Config` struct (around line 30)
3. Replace the computed properties with static values:

```swift
private struct Config {
    static let serviceName = "ai-clipboard"
    static let langfuseEndpoint = "https://cloud.langfuse.com/api/public/otel"
    static let publicKey = "pk-lf-your-public-key-here"
    static let secretKey = "sk-lf-your-secret-key-here"
}
```

⚠️ **Warning**: Never commit hardcoded API keys to version control!

---

## Step 3: Build and Run

1. **Clean Build Folder**:
   - In Xcode: **Product → Clean Build Folder** (⇧⌘K)

2. **Build the Project**:
   - **Product → Build** (⌘B)
   - Resolve any compilation errors

3. **Run the Application**:
   - **Product → Run** (⌘R)
   - Check the console for the tracing initialization message:
     ```
     ✅ Langfuse tracing initialized successfully
     ```

---

## Step 4: Verify Tracing Works

1. **Trigger an AI Call**:
   - Copy some text to your clipboard
   - Use a Prompt Tool (e.g., press the hotkey for "Markdown 格式化")
   - Wait for the AI to process

2. **Check Langfuse Dashboard**:
   - Go to your Langfuse project: https://cloud.langfuse.com
   - Navigate to **Traces**
   - You should see a new trace with:
     - Trace name: `prompt_tool.execute`
     - Child span: `ai.generate` or `gemini.generate`
     - Attributes: model, tokens, input/output

3. **Expected Trace Structure**:
   ```
   prompt_tool.execute (span)
   └── ai.generate (span)
       ├── gen_ai.system: "openai"
       ├── gen_ai.request.model: "gpt-4o-mini"
       ├── gen_ai.prompt: "user input..."
       ├── gen_ai.completion: "AI response..."
       ├── gen_ai.usage.prompt_tokens: 25
       └── gen_ai.usage.completion_tokens: 45
   ```

---

## What Gets Traced

### 1. Prompt Tool Execution
- **File**: `PromptToolManager.swift`
- **Span**: `prompt_tool.execute`
- **Attributes**:
  - `tool_name`: Name of the tool
  - `tool_id`: UUID of the tool
  - `is_default`: Whether it's a built-in tool
  - Input: Clipboard content
  - Output: AI-generated result

### 2. AI Service Calls (OpenAI, Claude, DeepSeek, etc.)
- **File**: `AIService.swift`
- **Span**: `ai.generate`
- **Attributes**:
  - `gen_ai.system`: Service type (openai, claude, etc.)
  - `gen_ai.request.model`: Model name
  - `gen_ai.prompt`: User input
  - `gen_ai.completion`: AI output
  - `gen_ai.usage.*`: Token counts

### 3. Gemini Service Calls
- **File**: `GeminiService.swift`
- **Spans**: `gemini.generate`, `gemini.generate_with_image`
- **Attributes**:
  - `gen_ai.system`: "gemini"
  - `gen_ai.request.model`: Model name
  - `gen_ai.prompt`: User input
  - `gen_ai.completion`: AI output
  - `has_image`: true (for Vision API)

### 4. Smart AI Recommendations
- **File**: `AIService.swift`
- **Span**: `ai.recommend_tool`
- **Attributes**:
  - `app_name`: Current application
  - `tools_count`: Number of available tools
  - `recommended_tool`: Selected tool name
  - `confidence`: Confidence score

---

## Troubleshooting

### Tracing Disabled Message

If you see:
```
⚠️ Langfuse tracing disabled: API keys not configured
```

**Solution**: Make sure environment variables are set correctly in Xcode scheme.

### No Traces in Langfuse

1. **Check API Keys**: Verify they're correct in Langfuse dashboard
2. **Check Network**: Ensure your Mac can reach `cloud.langfuse.com`
3. **Check Console**: Look for error messages in Xcode console
4. **Flush Traces**: Traces are sent asynchronously; wait a few seconds

### Compilation Errors

If you see `No such module 'OpenTelemetryApi'`:

**Solution**: Make sure you added the Swift packages correctly (Step 1)

### Build Errors

If you see linking errors:

**Solution**:
1. Clean build folder (⇧⌘K)
2. Delete derived data: `~/Library/Developer/Xcode/DerivedData`
3. Restart Xcode
4. Build again

---

## Advanced Configuration

### Change Langfuse Region

To use the US region instead of EU:

Edit `TracingService.swift` line 32:
```swift
static let langfuseEndpoint = "https://us.cloud.langfuse.com/api/public/otel"
```

### Self-Hosted Langfuse

If you're self-hosting Langfuse:

Edit `TracingService.swift` line 32:
```swift
static let langfuseEndpoint = "https://your-domain.com/api/public/otel"
```

### Disable Tracing

To temporarily disable tracing without removing code:

Set environment variable:
```
LANGFUSE_PUBLIC_KEY = (leave empty)
```

Or comment out the initialization in `AppDelegate.swift`:
```swift
// _ = TracingService.shared
```

---

## Files Modified

| File | Changes |
|------|---------|
| `TracingService.swift` | ✅ Created - OpenTelemetry initialization |
| `AIService.swift` | ✅ Added tracing to `generate()` and `recommendTool()` |
| `GeminiService.swift` | ✅ Added tracing to `generate()` and `generateWithImage()` |
| `PromptToolManager.swift` | ✅ Added tracing to `executeTool()` |
| `AppDelegate.swift` | ✅ Initialize TracingService on app launch |

---

## Next Steps

1. ✅ Complete Step 1-3 above
2. ✅ Verify traces appear in Langfuse
3. 📊 Explore your traces in the Langfuse dashboard
4. 🔍 Use Langfuse to debug AI issues
5. 📈 Monitor token usage and costs
6. 🎯 Optimize prompts based on trace data

---

## Support

- **Langfuse Docs**: https://langfuse.com/docs
- **OpenTelemetry Swift**: https://github.com/open-telemetry/opentelemetry-swift
- **Issues**: Raise an issue in your project repository

---

**Last Updated**: 2026-01-27

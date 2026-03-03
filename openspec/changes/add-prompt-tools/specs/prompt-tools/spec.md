# Prompt Tools Specification

## ADDED Requirements

### Requirement: Prompt Tool Management
The system SHALL provide the ability to create, read, update, and delete Prompt Tools, where each Tool consists of a name, prompt template, and optional global hotkey binding.

#### Scenario: Create new Tool
- **WHEN** user creates a new Tool with name "Format Markdown" and prompt "Convert the following text to well-formatted Markdown..."
- **THEN** the Tool is saved to the database with a unique ID
- **AND** the Tool appears in the Tool list in Settings

#### Scenario: Edit existing Tool
- **WHEN** user modifies the prompt of an existing Tool
- **THEN** the changes are persisted to the database
- **AND** the Tool's updatedAt timestamp is updated

#### Scenario: Delete Tool
- **WHEN** user deletes a Tool
- **THEN** the Tool is removed from the database
- **AND** any registered hotkey for that Tool is unregistered

#### Scenario: List all Tools
- **WHEN** user opens the Prompt Tools settings tab
- **THEN** all user-created and default Tools are displayed in a list
- **AND** each Tool shows its name and assigned hotkey (if any)

---

### Requirement: Tool Hotkey Binding
The system SHALL allow users to assign a unique global hotkey to each Prompt Tool for quick execution from any application.

#### Scenario: Assign hotkey to Tool
- **WHEN** user assigns hotkey ⌘⇧M to Tool "Format Markdown"
- **THEN** the hotkey is registered globally
- **AND** pressing ⌘⇧M from any application triggers the Tool execution

#### Scenario: Hotkey conflict detection
- **WHEN** user tries to assign a hotkey that is already in use by another Tool or system shortcut
- **THEN** the system displays a conflict warning
- **AND** prevents the duplicate assignment

#### Scenario: Remove hotkey from Tool
- **WHEN** user removes the hotkey from a Tool
- **THEN** the global hotkey registration is removed
- **AND** the Tool can still be executed from the UI

---

### Requirement: Tool Execution
The system SHALL execute a Prompt Tool by reading current clipboard content, sending it along with the Tool's prompt to the configured AI service, and writing the result back to the clipboard.

#### Scenario: Successful Tool execution
- **WHEN** user triggers Tool "Format Markdown" via hotkey
- **AND** clipboard contains "some unformatted text"
- **THEN** the system sends the text to the AI service with the Tool's prompt
- **AND** the AI response is written to the clipboard
- **AND** the original clipboard content is replaced

#### Scenario: Empty clipboard
- **WHEN** user triggers a Tool via hotkey
- **AND** clipboard is empty or contains non-text content
- **THEN** the system displays an error notification
- **AND** no AI API call is made

#### Scenario: Tool execution with auto-paste
- **WHEN** user executes a Tool with auto-paste enabled
- **THEN** after the result is written to clipboard
- **AND** the system automatically pastes the result to the active application

---

### Requirement: AI Service Integration
The system SHALL support multiple AI service providers through the MacPaw/OpenAI SDK with custom endpoint configuration, enabling compatibility with any OpenAI API-compatible service.

#### Scenario: OpenAI API integration
- **WHEN** user configures OpenAI as the AI service
- **AND** provides a valid API key
- **THEN** Tool execution uses OpenAI API (GPT-4o, GPT-4o-mini) for generation

#### Scenario: Claude API integration via compatible endpoint
- **WHEN** user configures Claude-compatible endpoint
- **AND** provides a valid Anthropic API key
- **THEN** Tool execution uses Claude API (Claude 3.5 Sonnet, Claude 3 Haiku) for generation

#### Scenario: Custom endpoint integration
- **WHEN** user configures a custom endpoint (DeepSeek, Moonshot, 智谱 GLM, etc.)
- **AND** provides the required API key
- **THEN** Tool execution uses the custom endpoint for generation

#### Scenario: Ollama local model integration
- **WHEN** user selects Ollama as the AI service
- **AND** Ollama is running locally with compatible endpoint
- **THEN** Tool execution uses local Ollama instance
- **AND** no API key is required

#### Scenario: AI service not configured
- **WHEN** user triggers a Tool
- **AND** no AI service is configured or API key is missing
- **THEN** the system displays configuration prompt
- **AND** opens the Prompt Tools settings

---

### Requirement: API Key Security
The system SHALL securely store AI service API keys in the macOS Keychain.

#### Scenario: Save API key
- **WHEN** user enters a Claude API key in settings
- **THEN** the key is stored in Keychain
- **AND** the key is NOT stored in plain text in UserDefaults or database

#### Scenario: Retrieve API key
- **WHEN** Tool execution requires the Claude API key
- **THEN** the key is retrieved from Keychain
- **AND** used for the API request

#### Scenario: Delete API key
- **WHEN** user clears the API key field
- **THEN** the key is removed from Keychain

---

### Requirement: Default Tool Collection
The system SHALL provide a set of 5 pre-configured default Tools that are initialized on first launch and can be restored by the user.

#### Scenario: First launch initialization
- **WHEN** user launches the app for the first time
- **THEN** 5 default Tools are created (Markdown格式化、表格生成、小红书成稿、邮件规范化、提取标题)
- **AND** each Tool has a predefined prompt template
- **AND** Tools are marked as isDefault=true

#### Scenario: Modify default Tool
- **WHEN** user edits a default Tool
- **THEN** the changes are saved
- **AND** the Tool remains marked as isDefault=true

#### Scenario: Delete default Tool
- **WHEN** user deletes a default Tool
- **THEN** the Tool is removed from the database
- **AND** can be restored via "Restore Defaults"

#### Scenario: Restore default Tools
- **WHEN** user clicks "Restore Default Tools" button
- **THEN** all missing default Tools are recreated
- **AND** existing default Tools are reset to original prompts
- **AND** user-created Tools are NOT affected

---

### Requirement: Error Handling
The system SHALL gracefully handle errors during Tool execution and provide informative feedback to the user.

#### Scenario: Network error
- **WHEN** Tool execution fails due to network connectivity
- **THEN** an error notification is displayed
- **AND** the original clipboard content is preserved

#### Scenario: API authentication error
- **WHEN** Tool execution fails due to invalid API key
- **THEN** an error notification indicates authentication failure
- **AND** user is prompted to check API key settings

#### Scenario: API rate limit error
- **WHEN** Tool execution fails due to API rate limiting
- **THEN** an error notification indicates rate limit
- **AND** suggests waiting before retrying

#### Scenario: API timeout
- **WHEN** Tool execution exceeds 30 seconds
- **THEN** the request is cancelled
- **AND** a timeout error notification is displayed

---

### Requirement: Prompt Tools Settings UI
The system SHALL provide a dedicated settings tab for managing Prompt Tools and AI service configuration.

#### Scenario: View settings tab
- **WHEN** user opens Settings and clicks "Prompt Tools" tab
- **THEN** the Tool list is displayed
- **AND** AI service selector is shown
- **AND** API key configuration field is shown

#### Scenario: Add new Tool from settings
- **WHEN** user clicks "Add Tool" button
- **THEN** a Tool editor sheet is presented
- **AND** user can enter name, prompt, and hotkey

#### Scenario: Edit Tool from settings
- **WHEN** user clicks edit button on a Tool
- **THEN** the Tool editor sheet is presented with current values
- **AND** user can modify and save changes

#### Scenario: Select AI service
- **WHEN** user selects a different AI service from dropdown
- **THEN** the selection is saved
- **AND** appropriate API key field is shown (or hidden for Ollama)

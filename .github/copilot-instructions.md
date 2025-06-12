# Copilot Instructions for VM Migration Tools

<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

## Project Context
This is a bash scripting project for OpenStack VM live migration with load balancing capabilities.

## Key Requirements
- Sequential VM migration (one at a time)
- Load balancing across target hosts
- Proper error handling and validation
- Support for both live migration and cold migration
- Logging and monitoring capabilities

## Code Style Guidelines
- Use bash best practices with proper error handling
- Include comprehensive logging
- Validate all inputs and preconditions
- Use modular functions for reusability
- Follow shellcheck recommendations

## OpenStack Context
- Focus on OpenStack nova commands
- Handle VM states (active, shutoff, etc.)
- Implement proper migration status checking
- Consider network and storage requirements

## Testing
- Include example configuration files
- Provide test scenarios and validation scripts
- Document troubleshooting procedures

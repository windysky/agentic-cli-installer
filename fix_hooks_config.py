#!/usr/bin/env python3
"""
Fix Claude Code hooks configuration to use the correct format.

Run this script in any directory containing a .claude/settings.json file
to fix the hooks configuration format.
"""

import json
import sys
from pathlib import Path


def fix_hooks_config(settings_path: Path) -> bool:
    """Fix hooks configuration in settings.json file."""
    try:
        # Read the current settings
        with open(settings_path, 'r', encoding='utf-8') as f:
            settings = json.load(f)

        if 'hooks' not in settings:
            print("No 'hooks' key found in settings.json")
            return False

        modified = False
        hooks = settings['hooks']

        # Fix SessionStart - wrap with hooks structure (no matcher for SessionStart/SessionEnd)
        if 'SessionStart' in hooks:
            session_start = hooks['SessionStart']
            # Check if it's using old format (direct array of hooks)
            if session_start:
                if 'hooks' not in session_start[0]:
                    # Old format: wrap with hooks
                    hooks['SessionStart'] = [
                        {
                            'hooks': session_start
                        }
                    ]
                    modified = True
                    print("Fixed: Wrapped SessionStart hooks (no matcher needed)")
                elif 'matcher' in session_start[0] and session_start[0]['matcher'] == {}:
                    # Has empty matcher that should be removed
                    del session_start[0]['matcher']
                    modified = True
                    print("Fixed: Removed empty matcher from SessionStart")

        # Fix SessionEnd - wrap with hooks structure (no matcher for SessionStart/SessionEnd)
        if 'SessionEnd' in hooks:
            session_end = hooks['SessionEnd']
            # Check if it's using old format (direct array of hooks)
            if session_end:
                if 'hooks' not in session_end[0]:
                    # Old format: wrap with hooks
                    hooks['SessionEnd'] = [
                        {
                            'hooks': session_end
                        }
                    ]
                    modified = True
                    print("Fixed: Wrapped SessionEnd hooks (no matcher needed)")
                elif 'matcher' in session_end[0] and session_end[0]['matcher'] == {}:
                    # Has empty matcher that should be removed
                    del session_end[0]['matcher']
                    modified = True
                    print("Fixed: Removed empty matcher from SessionEnd")

        # Fix PostToolUse - ensure matcher is a string
        if 'PostToolUse' in hooks:
            for hook_entry in hooks['PostToolUse']:
                if 'matcher' in hook_entry:
                    current_matcher = hook_entry['matcher']
                    if isinstance(current_matcher, dict):
                        # Convert object matcher to string pattern
                        if 'tools' in current_matcher:
                            tools = current_matcher['tools']
                            if isinstance(tools, list):
                                hook_entry['matcher'] = '|'.join(tools)
                            else:
                                hook_entry['matcher'] = str(tools)
                            modified = True
                            print(f"Fixed: Converted PostToolUse matcher to string: {hook_entry['matcher']}")
                        else:
                            # Empty dict, keep it as is for SessionStart/SessionEnd style
                            pass
                    elif not isinstance(current_matcher, str):
                        # Convert non-string matcher to string
                        hook_entry['matcher'] = str(current_matcher)
                        modified = True
                        print(f"Fixed: Converted PostToolUse matcher to string: {hook_entry['matcher']}")

        if not modified:
            print("No changes needed - hooks configuration is already correct")
            return True

        # Write back the fixed settings
        with open(settings_path, 'w', encoding='utf-8') as f:
            json.dump(settings, f, indent=2)
            f.write('\n')  # Add trailing newline

        print(f"Successfully fixed {settings_path}")
        return True

    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in {settings_path}: {e}")
        return False
    except Exception as e:
        print(f"Error: {e}")
        return False


def main():
    """Main entry point."""
    # Get the script's directory
    script_dir = Path(__file__).parent
    settings_path = script_dir / '.claude' / 'settings.json'

    # Check if settings.json exists
    if not settings_path.exists():
        print(f"Error: {settings_path} not found")
        print("Please run this script in a directory containing .claude/settings.json")
        sys.exit(1)

    print(f"Fixing hooks configuration in: {settings_path}")
    print("-" * 50)

    success = fix_hooks_config(settings_path)

    if success:
        print("-" * 50)
        print("Done!")
        sys.exit(0)
    else:
        print("-" * 50)
        print("Failed to fix hooks configuration")
        sys.exit(1)


if __name__ == '__main__':
    main()

# Design V2 Visual Overhaul — iOS

## Task
Implement the Design V2 visual overhaul for the DayCast iOS app to match the new web design.

## Steps

- [x] 1. Read all existing files to understand current state
- [x] 2. Update Theme.swift — color system, design tokens, reusable components (gradient bg, button styles, card modifiers, scroll-reveal)
- [x] 3. Update ContentView.swift — tab bar tint with gradient accent
- [x] 4. Update LoginView.swift — gradient mesh bg, input focus glow, gradient button
- [x] 5. Update FeedView.swift — flame animations, card styling, scroll reveal, button interactions
- [x] 6. Update GenerateView.swift — pulse animation on generate button, card shadows, scroll reveal, button interactions
- [x] 7. Update ChannelsView.swift — enhanced toggle spring, button interactions
- [x] 8. Update HistoryView.swift — scroll-triggered reveals, card styling
- [x] 9. Update HistoryDetailView.swift — card styling improvements
- [x] 10. Update BlogView.swift — card styling, scroll reveal
- [x] 11. Update BlogPostDetailView.swift — card styling
- [x] 12. Verify all files for syntax correctness

---

# Add Edit History Sheet + Context Menu to FeedView

## Task
Add an edit history sheet and context menu option to FeedView for viewing word-level diffs of previous item versions. All existing functionality (inline badge expansion, context menu items) must be preserved.

## Steps

- [x] 1. Add `@State private var editHistoryItem: InputItem?` state variable
- [x] 2. Add "Edit History" context menu option to existing context menu
- [x] 3. Create `EditHistorySheet` struct with NavigationStack, List, word-level diffs, and Done button
- [x] 4. Add `.sheet(item: $editHistoryItem)` modifier with presentation detents

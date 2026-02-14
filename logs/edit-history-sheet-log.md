# Log: Add Edit History Sheet + Context Menu to FeedView

## Step 1: Add state variable
- Added `@State private var editHistoryItem: InputItem?` to FeedView (line 48, after `expandedEdits`)
- This drives the sheet presentation

## Step 2: Add context menu option
- Added "Edit History (N)" button to the existing `.contextMenu` block
- Uses `clock.arrow.circlepath` SF Symbol
- Only shown when `item.edits` is not nil and not empty
- Placed before the destructive "Delete" button
- Sets `editHistoryItem = item` to trigger the sheet

## Step 3: Create EditHistorySheet struct
- Added `EditHistorySheet` struct before `#Preview`
- NavigationStack with List and "Previous Versions" section header
- Section header includes count badge (matching HistoryDetailView pattern)
- Each edit row shows word-level diff via `computeWordDiff` + `buildDiffText` (from HistoryDetailView.swift)
- Each edit row shows timestamp via `formatTime` (from Theme.swift)
- "Done" button in toolbar with `.dcBlue` color
- Navigation title: "Edit History"

## Step 4: Add sheet modifier
- Added `.sheet(item: $editHistoryItem)` after the existing edit sheet
- Includes `.presentationDetents([.medium, .large])` and `.presentationDragIndicator(.visible)`

## Notes
- All existing functionality preserved: inline badge expansion, existing context menu items, all state variables
- `InputItem` already conforms to `Identifiable` (via `let id: String`), so `.sheet(item:)` works
- `computeWordDiff`, `buildDiffText`, `DiffPart`, `formatTime` are all top-level functions already accessible

# Midnight UI

The selected direction is concept 03: navy surfaces (#111827), lime primary
(#BEF264), mint income, and pink expense. The shared Material 3 dark theme in
`mobile/lib/core/theme.dart` applies to authentication, four home tabs, editors,
dialogs, date pickers, and menus. Cards use 20dp corners; the full-width docked primary
action and navigation indicators use pill shapes. No dependencies were added.

The overview uses a gradient monthly net panel with responsive income/expense
metrics separated by dividers inside the same card (no nested metric cards).
The category ring sits beside its legend at regular text sizes; large text
reflows vertically. Recent transactions use compact rows. The six-month
comparison expands below the main overview. The primary action has a dedicated
layout region above navigation, so it cannot cover scroll content. Monthly net remains
income minus expense, not a bank balance. Recent transactions are fetched for the
selected month separately from transaction search/filter results. Tapping one
opens its editor; “Xem tất cả” opens the transaction tab.

Amounts and labels remain available as text independently of chart colors.
The ring has a screen-reader summary. Existing loading, empty, error and budget
warning states remain available. Layouts adapt to large system text and narrow
screens. Focus borders and semantic color pairs are covered by the existing
contrast suite; custom category colors are user data and remain unchanged.

Verification results are reported with the implementation. The widget suite
covers portrait/landscape phone, tablet and desktop sizes at 1x/2x text, all home
tabs, authentication, editors, keyboard focus and recent transaction navigation.

Validated with `flutter test --no-pub`: all 31 tests passed, including geometry checks for the ring/legend,
inline metrics, action dock, long VND values and 200% text.
`dart analyze lib` reports only the existing
`unawaited_return_in_try_block` warning in `core/api.dart:99`.
Flutter widget renders with loaded Roboto and Material icon fonts were also
inspected at 360x800 for ordinary and multi-billion VND data. See
`midnight-standard.png` and `midnight-long.png` (mock data). These are widget
renders, not screenshots from a physical device.


## Management screens

`mobile/lib/widgets/management_views.dart` owns the transaction, budget and
category layouts. Home retains API loading, pagination, route navigation and
delete confirmation. Existing data and endpoint contracts are preserved.

Transactions show the selected month's income and expense independently of
search results, a labeled search field with clear/search actions, filter pills,
and dated groups with signed amounts, payment methods and edit/delete menus.
Budgets summarize only categories with an assigned budget, then show individual
limits, spending, remaining/overspent amounts and labeled progress states.
The near-limit state starts at 80%; over-limit amounts retain an explicit label.
Categories use separate income/expense groups and responsive icon cards.
Icons are inferred from existing category names, with generic fallbacks; no
additional stored data or dependencies are required.

Cards wrap based on available width without fixed heights, switching to one
column at large text sizes. Integration tests cover editing and canceling delete
for each tab, search/filter/clear request parameters, long amounts/names and
200% text. The existing suite also covers phone, landscape, tablet and desktop.
Preview renders at 390x844 with mock data: `midnight-transactions.png`,
`midnight-budgets.png`, and `midnight-categories.png`.

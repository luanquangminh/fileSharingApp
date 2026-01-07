# Implementation Plan Summary: Login/Logout Functionality

**Plan Location:** `/Users/minhbohung111/workspace/projects/networkFinal/plans/20260103-2051-login-logout-functionality/plan.md`

**Created:** 2026-01-03
**Estimated Effort:** 8-12 hours
**Complexity:** Medium

---

## Overview

Add logout capability to GTK GUI client enabling users to logout and re-login with different credentials without restarting the application. Support seamless transitions between regular user and admin dashboards.

---

## Key Requirements

1. Add logout button to File menu (both main window and admin dashboard)
2. Logout disconnects session and shows login dialog
3. Support re-login with same or different credentials
4. Handle user type transitions (regular ↔ admin)
5. Logout confirmation to prevent accidents
6. Cancel re-login exits application

---

## Architecture Decisions

### Window Management
**Strategy:** Destroy/recreate windows on logout/login
- Simpler state management
- Cleaner memory profile
- Handles user type switching naturally

### Connection Management
**Strategy:** Full disconnect and reconnect
- Reliable and clean state
- Matches existing architecture
- No protocol changes needed (no CMD_LOGOUT in protocol)

### Re-login Cancel Behavior
**Strategy:** Exit application on cancel
- Simpler UX
- Clearer user intent

---

## Implementation Phases

### Phase 1: Login Logic Refactoring
- Extract `perform_login()` reusable function
- Add `LoginResult` struct
- Handle connection and authentication with retry logic
**Files:** `login_dialog.c`, `gui.h`

### Phase 2: Main Window Logout
- Add logout menu item
- Implement logout callback with confirmation
- Add window destroy handler
**Files:** `main_window.c`

### Phase 3: Admin Dashboard Logout
- Add File menu bar to admin dashboard
- Implement logout menu and callback
- Update destroy handler
**Files:** `admin_dashboard.c`, `admin_dashboard.h`

### Phase 4: Main Loop Refactoring
- Refactor `main()` to login loop
- Support logout → re-login flow
- Handle user type switching
- Use global flag to distinguish logout from quit
**Files:** `main.c`

### Phase 5: Admin Dashboard State Management
- Change `create_admin_dashboard()` return type to `AdminState*`
- Ensure proper state cleanup
**Files:** `admin_dashboard.c`, `admin_dashboard.h`

### Phase 6: Polish (Optional)
- Add "Connecting..." loading indicators
- Update status bar on login
**Files:** `login_dialog.c`, `main_window.c`

### Phase 7: Testing & Validation
- Basic logout/login cycles
- User type switching
- Cancel behaviors
- Connection failures
- Memory leak testing (valgrind)
- Multiple cycles stress testing

---

## Files Modified

| File | Changes | LOC |
|------|---------|-----|
| `src/client/gui/gui.h` | Add LoginResult, perform_login() | +10 |
| `src/client/gui/login_dialog.c` | Add perform_login() function | +80 |
| `src/client/gui/main_window.c` | Logout menu, callbacks, handlers | +40 |
| `src/client/gui/admin_dashboard.c` | Menu bar, logout functionality | +60 |
| `src/client/gui/admin_dashboard.h` | Update return type | +1 |
| `src/client/gui/main.c` | Login loop refactoring | +30 |
| **Total** | | **~220** |

---

## Critical Implementation Details

### Global Logout Flag
```c
static gboolean g_logout_requested = FALSE;
```
Distinguishes logout (loop continues) from quit (exit app).

### Main Loop Pattern
```c
while (1) {
    g_logout_requested = FALSE;
    LoginResult *result = perform_login(NULL);
    if (cancelled) break;

    // Create and show window based on user type
    gtk_main(); // Blocks until logout or quit

    if (!g_logout_requested) break; // Quit
    // Otherwise loop continues for re-login
}
```

### Logout Handler Pattern
```c
static void on_logout_activate(GtkWidget *widget, AppState *state) {
    // Show confirmation
    if (confirmed) {
        g_logout_requested = TRUE;
        client_disconnect(state->conn);
        gtk_main_quit(); // Returns to main loop
    }
}
```

---

## Test Scenarios (15 Total)

Key tests:
- Basic logout/login cycle
- User type switching (admin ↔ regular)
- Cancel confirmation
- Cancel re-login (should exit)
- Connection failures with retry
- Multiple cycles (10+)
- Memory leak validation (valgrind)
- Window destroy (quit)
- UI responsiveness

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Memory leaks | Valgrind testing, careful state cleanup |
| GTK main loop issues | Thorough testing of quit/re-entry |
| User type switching bugs | Comprehensive transition testing |

---

## Success Criteria

✅ Logout works in both windows
✅ Login dialog appears after logout
✅ Re-login with different credentials works
✅ User type transitions work
✅ Confirmation prevents accidents
✅ No memory leaks (valgrind clean)
✅ All 15 test cases pass
✅ No regressions

---

## No Server Changes Required

Protocol has no `CMD_LOGOUT`. Client-side disconnect is sufficient.

---

## Estimated Timeline

- Phase 1-5: 5-6 hours (implementation)
- Phase 6: 0.5 hours (polish)
- Phase 7: 2-3 hours (testing)
- Phase 8: 0.5 hours (documentation)

**Total: 8-12 hours**

---

## Next Actions

1. Review plan
2. Start Phase 1: Refactor login logic
3. Proceed sequentially through phases
4. Test after each phase
5. Final integration testing
6. Commit changes

---

For complete details, code snippets, and testing checklist, see full plan:
**`/Users/minhbohung111/workspace/projects/networkFinal/plans/20260103-2051-login-logout-functionality/plan.md`**

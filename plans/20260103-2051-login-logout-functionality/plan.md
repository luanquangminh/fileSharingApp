# Implementation Plan: Login/Logout Functionality for GTK GUI Client

**Created:** 2026-01-03
**Status:** Draft
**Complexity:** Medium
**Estimated Effort:** 8-12 hours

## Executive Summary

Add logout capability to GTK GUI client, allowing users to logout and re-login with different credentials without restarting the application. Support seamless transitions between regular user and admin dashboards.

## Current State Analysis

### Architecture Overview

**Login Flow (main.c:10-58)**
- Single modal login dialog at startup
- Dialog destroyed immediately after authentication
- Connection lifecycle bound to application lifecycle
- Routes users to admin dashboard or file browser based on `is_admin` flag

**Connection Management (client.c)**
- `client_connect()`: Socket connection creation
- `client_login()`: Authentication with username/password
- `client_disconnect()`: Socket closure and memory cleanup
- No session reset or re-login capability

**UI Windows**
- Main Window (regular users): File browser with menu bar (File > Quit only)
- Admin Dashboard: User management interface
- Both windows lack logout functionality
- No window state management for hide/show

**Key Data Structures**
```c
// ClientConnection (client.h)
typedef struct {
    int socket_fd;
    char server_ip[64];
    int server_port;
    int authenticated;      // Session state flag
    int user_id;
    int is_admin;
    int current_directory;
    char current_path[512];
} ClientConnection;

// AppState (gui.h) - Regular users
typedef struct {
    GtkWidget *window;
    GtkWidget *tree_view;
    GtkListStore *file_store;
    GtkWidget *status_bar;
    ClientConnection *conn;
    int current_directory;
    char current_path[512];
} AppState;

// AdminState (admin_dashboard.h) - Admin users
typedef struct {
    GtkWidget *window;
    GtkWidget *tree_view;
    GtkListStore *user_store;
    GtkWidget *status_bar;
    ClientConnection *conn;
} AdminState;
```

### Protocol Analysis (protocol.h)

**Available Commands:**
- `CMD_LOGIN_REQ (0x01)` / `CMD_LOGIN_RES (0x02)` - Login authentication
- No `CMD_LOGOUT_REQ` or `CMD_LOGOUT_RES` defined

**Implication:** No server-side logout protocol. Client-side session reset sufficient.

### Critical Issues

1. **No Logout Mechanism:** Users cannot logout without closing app
2. **Dialog Not Reusable:** Login dialog destroyed after first use
3. **Missing Cleanup Handlers:** No `on_window_destroy()` callbacks (potential memory leaks)
4. **User Type Switching:** Cannot switch between admin/regular windows
5. **Connection State Coupling:** Connection tied to app lifecycle, not session lifecycle

## Requirements

### Functional Requirements

1. **FR-1:** Add logout button to File menu in both main window and admin dashboard
2. **FR-2:** Logout shall disconnect current session and show login dialog
3. **FR-3:** Support re-login with same or different credentials
4. **FR-4:** Handle user type transitions (regular ↔ admin)
5. **FR-5:** Logout confirmation dialog to prevent accidental logouts
6. **FR-6:** Cancel re-login shall exit application

### Non-Functional Requirements

1. **NFR-1:** No memory leaks on repeated logout/login cycles
2. **NFR-2:** UI remains responsive during network operations
3. **NFR-3:** Graceful error handling for connection failures
4. **NFR-4:** Maintain existing code patterns and style

## Solution Design

### Design Decisions

**Decision 1: Window Management Strategy**

**Options:**
- **Option A:** Hide/show windows on logout/login
  - Pros: Faster transitions, preserve UI state
  - Cons: Complex state management, user type switching requires conditional destroy

- **Option B:** Destroy/recreate windows on logout/login
  - Pros: Simpler state management, cleaner memory, handles user type switching naturally
  - Cons: Slightly slower transitions, lose UI state (scroll position, etc.)

**Choice:** **Option B** - Destroy/recreate for simplicity, cleaner memory profile

**Decision 2: Connection Management Strategy**

**Options:**
- **Option A:** Keep socket alive, reset session state only
  - Pros: Faster re-login, less network overhead
  - Cons: Stale connection risks, server may timeout, no protocol support

- **Option B:** Full disconnect and reconnect
  - Pros: Clean state, reliable, matches existing architecture
  - Cons: Network overhead

**Choice:** **Option B** - Full disconnect/reconnect for reliability

**Decision 3: Re-login Cancel Behavior**

**Options:**
- **Option A:** Return to unauthenticated state, show empty window
- **Option B:** Exit application

**Choice:** **Option B** - Exit on cancel (simpler UX, clearer intent)

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        Application State                     │
│  ┌──────────┐      ┌──────────┐      ┌─────────────────┐   │
│  │  LOGIN   │─────→│ MAIN WIN │◄────→│ ADMIN DASHBOARD │   │
│  └──────────┘      └──────────┘      └─────────────────┘   │
│       ▲                 │                      │             │
│       │              LOGOUT                 LOGOUT           │
│       └─────────────────┴──────────────────────┘             │
└─────────────────────────────────────────────────────────────┘

Logout Flow:
1. User clicks File > Logout
2. Show confirmation dialog
3. Disconnect and free connection
4. Destroy current window and state
5. Show login dialog
6. On success: Create new connection, window, state
7. On cancel: Exit application
```

### Component Interaction

```
main.c
  ├─ gtk_init()
  ├─ login_loop() ◄─── NEW: Reusable login loop
  │   ├─ show_login_dialog()
  │   ├─ perform_login()
  │   └─ route_user()
  │       ├─ create_main_window() + gtk_main()
  │       └─ create_admin_dashboard() + gtk_main()
  └─ cleanup()

main_window.c / admin_dashboard.c
  ├─ create_window()
  │   └─ Add File > Logout menu item
  ├─ on_logout_activate() ◄─── NEW: Logout handler
  │   ├─ show_confirmation_dialog()
  │   ├─ client_disconnect()
  │   ├─ gtk_main_quit() ─────────► Returns to login_loop()
  │   └─ destroy_window()
  └─ on_window_destroy() ◄─── NEW: Cleanup handler

login_dialog.c
  ├─ create_login_dialog() (unchanged)
  └─ perform_login() ◄─── NEW: Extracted login logic
      ├─ client_connect()
      ├─ client_login()
      └─ error handling

client.c
  └─ (No changes needed - use existing disconnect/connect)
```

## Implementation Phases

### Phase 1: Refactor Login Logic (Foundation)

**Files:** `src/client/gui/login_dialog.c`, `src/client/gui/gui.h`

**Task 1.1: Extract login logic into reusable function**
```c
// Add to login_dialog.c
typedef struct {
    ClientConnection *conn;
    int is_cancelled;
} LoginResult;

LoginResult* perform_login(GtkWidget *parent_window) {
    LoginResult *result = g_new0(LoginResult, 1);

    while (1) {
        GtkWidget *login_dialog = create_login_dialog();
        if (parent_window) {
            gtk_window_set_transient_for(GTK_WINDOW(login_dialog),
                                        GTK_WINDOW(parent_window));
        }

        gint response = gtk_dialog_run(GTK_DIALOG(login_dialog));

        if (response != GTK_RESPONSE_OK) {
            result->is_cancelled = 1;
            gtk_widget_destroy(login_dialog);
            return result;
        }

        // Extract credentials (copy before destroying dialog)
        GtkWidget *server_entry = g_object_get_data(G_OBJECT(login_dialog), "server_entry");
        GtkWidget *port_entry = g_object_get_data(G_OBJECT(login_dialog), "port_entry");
        GtkWidget *username_entry = g_object_get_data(G_OBJECT(login_dialog), "username_entry");
        GtkWidget *password_entry = g_object_get_data(G_OBJECT(login_dialog), "password_entry");

        char server[256], username[256], password[256], port_str[16];
        strncpy(server, gtk_entry_get_text(GTK_ENTRY(server_entry)), sizeof(server) - 1);
        strncpy(port_str, gtk_entry_get_text(GTK_ENTRY(port_entry)), sizeof(port_str) - 1);
        strncpy(username, gtk_entry_get_text(GTK_ENTRY(username_entry)), sizeof(username) - 1);
        strncpy(password, gtk_entry_get_text(GTK_ENTRY(password_entry)), sizeof(password) - 1);

        server[sizeof(server) - 1] = '\0';
        username[sizeof(username) - 1] = '\0';
        password[sizeof(password) - 1] = '\0';
        int port = atoi(port_str);

        gtk_widget_destroy(login_dialog);

        // Process pending events to fully destroy dialog
        while (gtk_events_pending()) {
            gtk_main_iteration();
        }

        // Attempt connection
        ClientConnection *conn = client_connect(server, port);
        if (!conn) {
            show_error_dialog(parent_window,
                "Failed to connect to server. Please check server address and try again.");
            continue; // Retry
        }

        // Attempt authentication
        if (client_login(conn, username, password) < 0) {
            show_error_dialog(parent_window,
                "Login failed. Invalid credentials.");
            client_disconnect(conn);
            continue; // Retry
        }

        // Success
        result->conn = conn;
        result->is_cancelled = 0;
        return result;
    }
}
```

**Task 1.2: Update gui.h**
```c
// Add to gui.h
typedef struct {
    ClientConnection *conn;
    int is_cancelled;
} LoginResult;

LoginResult* perform_login(GtkWidget *parent_window);
void login_result_free(LoginResult *result);
```

**Acceptance Criteria:**
- `perform_login()` returns NULL on cancel
- Returns valid `ClientConnection*` on success
- Shows error dialogs on failure and allows retry
- Login dialog properly destroyed after use

---

### Phase 2: Main Window Logout Implementation

**Files:** `src/client/gui/main_window.c`, `src/client/gui/gui.h`

**Task 2.1: Add logout menu item**
```c
// In create_main_window(), after quit_item creation (line 23)

GtkWidget *logout_item = gtk_menu_item_new_with_label("Logout");
g_signal_connect(logout_item, "activate", G_CALLBACK(on_logout_activate), state);
gtk_menu_shell_append(GTK_MENU_SHELL(file_menu), logout_item);

// Separator
GtkWidget *separator = gtk_separator_menu_item_new();
gtk_menu_shell_append(GTK_MENU_SHELL(file_menu), separator);

// Then add quit_item
```

**Task 2.2: Implement logout callback**
```c
// Add to main_window.c
static void on_logout_activate(GtkWidget *widget, AppState *state) {
    // Confirmation dialog
    GtkWidget *dialog = gtk_message_dialog_new(
        GTK_WINDOW(state->window),
        GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
        GTK_MESSAGE_QUESTION,
        GTK_BUTTONS_YES_NO,
        "Are you sure you want to logout?"
    );

    gint response = gtk_dialog_run(GTK_DIALOG(dialog));
    gtk_widget_destroy(dialog);

    if (response == GTK_RESPONSE_YES) {
        // Logout: disconnect and quit main loop
        client_disconnect(state->conn);
        state->conn = NULL;

        // This will return control to main.c login loop
        gtk_main_quit();
    }
}
```

**Task 2.3: Add window destroy handler**
```c
// Modify create_main_window() destroy signal (line 11)
// Remove: g_signal_connect(window, "destroy", G_CALLBACK(gtk_main_quit), NULL);
// Add:
g_signal_connect(window, "destroy", G_CALLBACK(on_main_window_destroy), state);

// Add handler
static void on_main_window_destroy(GtkWidget *widget, AppState *state) {
    if (state->conn) {
        client_disconnect(state->conn);
        state->conn = NULL;
    }
    gtk_main_quit();
}
```

**Acceptance Criteria:**
- Logout menu item visible in File menu
- Clicking logout shows confirmation dialog
- Yes: disconnects, returns to login
- No: cancels logout, returns to window
- Window destroy properly cleans up connection

---

### Phase 3: Admin Dashboard Logout Implementation

**Files:** `src/client/gui/admin_dashboard.c`, `src/client/gui/admin_dashboard.h`

**Task 3.1: Add File menu with logout**
```c
// In create_admin_dashboard(), add menu bar creation
// (Currently admin dashboard has no menu bar - add similar to main_window.c)

GtkWidget *menubar = gtk_menu_bar_new();

// File menu
GtkWidget *file_menu = gtk_menu_new();
GtkWidget *file_item = gtk_menu_item_new_with_label("File");

GtkWidget *logout_item = gtk_menu_item_new_with_label("Logout");
g_signal_connect(logout_item, "activate", G_CALLBACK(on_admin_logout_activate), state);
gtk_menu_shell_append(GTK_MENU_SHELL(file_menu), logout_item);

GtkWidget *separator = gtk_separator_menu_item_new();
gtk_menu_shell_append(GTK_MENU_SHELL(file_menu), separator);

GtkWidget *quit_item = gtk_menu_item_new_with_label("Quit");
g_signal_connect(quit_item, "activate", G_CALLBACK(on_admin_quit_activate), state);
gtk_menu_shell_append(GTK_MENU_SHELL(file_menu), quit_item);

gtk_menu_item_set_submenu(GTK_MENU_ITEM(file_item), file_menu);
gtk_menu_shell_append(GTK_MENU_SHELL(menubar), file_item);

gtk_box_pack_start(GTK_BOX(vbox), menubar, FALSE, FALSE, 0);
```

**Task 3.2: Implement logout callback**
```c
// Add to admin_dashboard.c
static void on_admin_logout_activate(GtkWidget *widget, AdminState *state) {
    GtkWidget *dialog = gtk_message_dialog_new(
        GTK_WINDOW(state->window),
        GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
        GTK_MESSAGE_QUESTION,
        GTK_BUTTONS_YES_NO,
        "Are you sure you want to logout?"
    );

    gint response = gtk_dialog_run(GTK_DIALOG(dialog));
    gtk_widget_destroy(dialog);

    if (response == GTK_RESPONSE_YES) {
        client_disconnect(state->conn);
        state->conn = NULL;
        gtk_main_quit();
    }
}

static void on_admin_quit_activate(GtkWidget *widget, AdminState *state) {
    gtk_main_quit();
}
```

**Task 3.3: Update on_window_destroy in admin_dashboard.c**
```c
// Modify existing on_window_destroy() (line 24)
static void on_window_destroy(GtkWidget *widget, AdminState *state) {
    if (state && state->conn) {
        client_disconnect(state->conn);
        state->conn = NULL;
    }

    if (state) {
        g_free(state);
    }

    gtk_main_quit();
}
```

**Acceptance Criteria:**
- Admin dashboard has File menu with Logout and Quit
- Logout shows confirmation dialog
- Proper cleanup on logout and window destroy

---

### Phase 4: Refactor main.c for Logout Loop

**Files:** `src/client/gui/main.c`

**Task 4.1: Refactor main() to support logout loop**
```c
// Replace entire main() function
int main(int argc, char *argv[]) {
    gtk_init(&argc, &argv);

    // Main login loop - allows logout and re-login
    while (1) {
        // Show login dialog
        LoginResult *login_result = perform_login(NULL);

        // Check if user cancelled
        if (login_result->is_cancelled || !login_result->conn) {
            login_result_free(login_result);
            break; // Exit application
        }

        ClientConnection *conn = login_result->conn;
        login_result_free(login_result);

        // Route based on user type
        if (conn->is_admin) {
            // Admin dashboard
            AdminState *admin_state = create_admin_dashboard(conn);
            gtk_main(); // Blocks until logout or quit

            // After gtk_main() returns (logout or window close)
            // Check if connection was closed (logout) or window destroyed (quit)
            // Connection is already freed in logout/destroy handlers
            // If we reach here after logout, loop continues to show login again

        } else {
            // Regular user file browser
            AppState *state = g_new0(AppState, 1);
            state->conn = conn;
            state->current_directory = 0;
            strcpy(state->current_path, "/");

            state->window = create_main_window(state);
            gtk_widget_show_all(state->window);
            refresh_file_list(state);

            gtk_main(); // Blocks until logout or quit

            // Cleanup state (connection freed in handlers)
            g_free(state);
        }

        // Note: If window was destroyed (quit), we also exit loop
        // Need way to distinguish logout from quit
        // Solution: Use global flag or check connection state
    }

    return 0;
}
```

**Task 4.2: Add state tracking to distinguish logout from quit**
```c
// Add global variable at top of main.c
static gboolean g_logout_requested = FALSE;

// Modify logout handlers to set flag
static void on_logout_activate(GtkWidget *widget, AppState *state) {
    // ... confirmation dialog ...
    if (response == GTK_RESPONSE_YES) {
        g_logout_requested = TRUE;
        client_disconnect(state->conn);
        state->conn = NULL;
        gtk_main_quit();
    }
}

// Modify main loop
int main(int argc, char *argv[]) {
    gtk_init(&argc, &argv);

    while (1) {
        g_logout_requested = FALSE; // Reset flag

        LoginResult *login_result = perform_login(NULL);
        if (login_result->is_cancelled || !login_result->conn) {
            login_result_free(login_result);
            break;
        }

        ClientConnection *conn = login_result->conn;
        login_result_free(login_result);

        if (conn->is_admin) {
            create_admin_dashboard(conn);
            gtk_main();
        } else {
            AppState *state = g_new0(AppState, 1);
            state->conn = conn;
            state->current_directory = 0;
            strcpy(state->current_path, "/");
            state->window = create_main_window(state);
            gtk_widget_show_all(state->window);
            refresh_file_list(state);
            gtk_main();
            g_free(state);
        }

        // If logout was not requested, break loop (user quit)
        if (!g_logout_requested) {
            break;
        }
        // Otherwise, loop continues to show login again
    }

    return 0;
}
```

**Task 4.3: Update logout handlers to set flag**

Update both `on_logout_activate()` and `on_admin_logout_activate()` to set `g_logout_requested = TRUE` before `gtk_main_quit()`.

**Acceptance Criteria:**
- Application shows login dialog on startup
- After logout, login dialog shown again
- After quit, application exits
- User type transitions work (admin ↔ regular)
- No memory leaks on repeated cycles

---

### Phase 5: Handle Admin Dashboard Return Value

**Files:** `src/client/gui/admin_dashboard.c`, `src/client/gui/admin_dashboard.h`

**Task 5.1: Modify create_admin_dashboard() signature**

Currently `create_admin_dashboard()` returns `GtkWidget*` but in main.c we need `AdminState*` to manage state.

**Option A:** Change return type to `AdminState*`
```c
// admin_dashboard.h
AdminState* create_admin_dashboard(ClientConnection *conn);

// admin_dashboard.c
AdminState* create_admin_dashboard(ClientConnection *conn) {
    AdminState *state = g_new0(AdminState, 1);
    state->conn = conn;

    // ... create window and widgets ...

    gtk_widget_show_all(state->window);
    return state;
}

// main.c usage
AdminState *admin_state = create_admin_dashboard(conn);
gtk_main();
// Don't free admin_state here - freed in destroy handler
```

**Option B:** Keep current signature, manage state internally
- Less intrusive
- State freed in destroy handler

**Choice:** **Option A** for consistency with main window pattern

**Acceptance Criteria:**
- Admin dashboard state properly managed
- No memory leaks on logout cycles

---

### Phase 6: Add Loading Indicators (Optional Enhancement)

**Files:** `src/client/gui/login_dialog.c`

**Task 6.1: Show "Connecting..." message during login**
```c
// In perform_login(), before client_connect()
GtkWidget *connecting_dialog = gtk_message_dialog_new(
    parent_window ? GTK_WINDOW(parent_window) : NULL,
    GTK_DIALOG_MODAL,
    GTK_MESSAGE_INFO,
    GTK_BUTTONS_NONE,
    "Connecting to server..."
);
gtk_widget_show_all(connecting_dialog);

// Process events to show dialog
while (gtk_events_pending()) {
    gtk_main_iteration();
}

ClientConnection *conn = client_connect(server, port);

gtk_widget_destroy(connecting_dialog);
```

**Acceptance Criteria:**
- User sees feedback during connection attempt
- UI doesn't freeze during network operations

---

### Phase 7: Testing & Validation

**Test Scenarios:**

1. **Basic Logout/Login Cycle**
   - Login as regular user
   - Logout
   - Verify login dialog shown
   - Re-login with same credentials
   - Verify file browser shown

2. **User Type Switching**
   - Login as regular user
   - Logout
   - Login as admin user
   - Verify admin dashboard shown
   - Logout
   - Login as regular user
   - Verify file browser shown

3. **Cancel Behaviors**
   - Login successfully
   - Click logout
   - Cancel confirmation → Verify window remains
   - Click logout again
   - Confirm logout
   - Cancel re-login → Verify app exits

4. **Connection Failures**
   - Logout
   - Enter invalid server address
   - Verify error dialog shown
   - Verify login dialog shown again (retry)
   - Enter valid credentials
   - Verify successful login

5. **Multiple Logout/Login Cycles**
   - Perform 5+ logout/login cycles
   - Check memory usage with `top` or `valgrind`
   - Verify no memory leaks

6. **Window Destroy (Quit)**
   - Login
   - Close window via window manager (X button)
   - Verify app exits cleanly
   - Verify no crashes or errors

7. **Rapid Actions**
   - Login
   - Quickly click logout and confirm
   - Verify no crashes
   - Test UI responsiveness

**Memory Leak Testing:**
```bash
# Run with valgrind
valgrind --leak-check=full --show-leak-kinds=all ./gui_client

# Perform logout/login cycles
# Check for "definitely lost" leaks
```

---

## Implementation Checklist

### Phase 1: Login Logic Refactoring
- [ ] Create `LoginResult` struct in `gui.h`
- [ ] Implement `perform_login()` in `login_dialog.c`
- [ ] Implement `login_result_free()` helper
- [ ] Update `gui.h` with new declarations
- [ ] Test login dialog in isolation

### Phase 2: Main Window Logout
- [ ] Add logout menu item to main window
- [ ] Implement `on_logout_activate()` callback
- [ ] Add confirmation dialog
- [ ] Implement `on_main_window_destroy()` handler
- [ ] Add global `g_logout_requested` flag
- [ ] Update destroy signal connection
- [ ] Test logout flow

### Phase 3: Admin Dashboard Logout
- [ ] Add File menu bar to admin dashboard
- [ ] Add logout menu item
- [ ] Implement `on_admin_logout_activate()` callback
- [ ] Implement `on_admin_quit_activate()` callback
- [ ] Update `on_window_destroy()` handler
- [ ] Test admin logout flow

### Phase 4: Main Loop Refactoring
- [ ] Refactor `main()` to use login loop
- [ ] Integrate `perform_login()` call
- [ ] Handle login cancellation (exit app)
- [ ] Handle logout (re-show login)
- [ ] Handle quit (exit app)
- [ ] Test user type transitions

### Phase 5: Admin Dashboard State Management
- [ ] Change `create_admin_dashboard()` return type to `AdminState*`
- [ ] Update function signature in header
- [ ] Update main.c usage
- [ ] Ensure state cleanup in destroy handler

### Phase 6: Polish (Optional)
- [ ] Add "Connecting..." loading indicator
- [ ] Add "Logging out..." message
- [ ] Update status bar on successful login
- [ ] Test UI responsiveness

### Phase 7: Testing & Validation
- [ ] Test basic logout/login cycle
- [ ] Test user type switching (admin ↔ regular)
- [ ] Test cancel confirmation
- [ ] Test cancel re-login
- [ ] Test connection failures
- [ ] Test multiple cycles (5+)
- [ ] Test window destroy (quit)
- [ ] Run valgrind for memory leaks
- [ ] Test rapid actions

### Phase 8: Code Review & Documentation
- [ ] Review all changes
- [ ] Add function documentation comments
- [ ] Update any existing documentation
- [ ] Create git commit

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Memory leaks on repeated cycles | Medium | High | Thorough testing with valgrind, careful state cleanup |
| GTK main loop issues | Low | High | Test gtk_main_quit() and re-entry thoroughly |
| User type switching bugs | Medium | Medium | Comprehensive testing of all transitions |
| Connection state corruption | Low | Medium | Use existing disconnect/connect, no custom state |
| UI freezing during network ops | Low | Low | Keep existing blocking behavior (acceptable for this app) |

---

## Edge Cases

1. **Server disconnects during session:** Not handled in this plan (out of scope). Would require server heartbeat/reconnect logic.

2. **Rapid logout/login clicks:** GTK event queue handles this naturally. No special handling needed.

3. **Window destroyed during logout confirmation:** Dialog is modal and child of window, so destroyed with parent. Safe.

4. **Login fails after multiple attempts:** `perform_login()` loops indefinitely until success or cancel. User can always cancel.

5. **User closes login dialog with window manager X button:** Returns `GTK_RESPONSE_DELETE_EVENT` which is != `GTK_RESPONSE_OK`, treated as cancel.

---

## Files Modified Summary

| File | Changes | LOC Impact |
|------|---------|------------|
| `src/client/gui/gui.h` | Add `LoginResult` struct, `perform_login()` declaration | +10 |
| `src/client/gui/login_dialog.c` | Add `perform_login()` function | +80 |
| `src/client/gui/main_window.c` | Add logout menu, callbacks, destroy handler | +40 |
| `src/client/gui/admin_dashboard.c` | Add menu bar, logout menu, callbacks | +60 |
| `src/client/gui/admin_dashboard.h` | Change return type of `create_admin_dashboard()` | +1 |
| `src/client/gui/main.c` | Refactor to login loop | +30 (net) |
| **Total** | | **~220 LOC** |

---

## Alternatives Considered

### Alternative 1: Add CMD_LOGOUT to Protocol

**Description:** Define server-side logout command

**Pros:**
- Server can track sessions
- Can implement session timeout
- More "proper" architecture

**Cons:**
- Requires server changes
- Current protocol has no logout
- Adds complexity for marginal benefit
- Client-side disconnect is sufficient

**Decision:** Rejected. Use client-side disconnect only.

---

### Alternative 2: Hide/Show Windows Instead of Destroy/Recreate

**Description:** Keep windows alive, toggle visibility

**Pros:**
- Faster logout/login
- Preserve UI state (scroll position, etc.)

**Cons:**
- More complex state management
- User type switching requires conditional logic
- Must handle stale data in UI
- Memory always allocated for both window types

**Decision:** Rejected. Destroy/recreate is simpler and cleaner.

---

## Appendix A: Code Snippets

### Logout Handler Template
```c
static void on_logout_activate(GtkWidget *widget, AppState *state) {
    GtkWidget *dialog = gtk_message_dialog_new(
        GTK_WINDOW(state->window),
        GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
        GTK_MESSAGE_QUESTION,
        GTK_BUTTONS_YES_NO,
        "Are you sure you want to logout?"
    );

    gint response = gtk_dialog_run(GTK_DIALOG(dialog));
    gtk_widget_destroy(dialog);

    if (response == GTK_RESPONSE_YES) {
        extern gboolean g_logout_requested;
        g_logout_requested = TRUE;

        if (state->conn) {
            client_disconnect(state->conn);
            state->conn = NULL;
        }

        gtk_main_quit();
    }
}
```

### Main Loop Template
```c
int main(int argc, char *argv[]) {
    gtk_init(&argc, &argv);

    while (1) {
        g_logout_requested = FALSE;

        LoginResult *result = perform_login(NULL);
        if (result->is_cancelled || !result->conn) {
            login_result_free(result);
            break;
        }

        ClientConnection *conn = result->conn;
        login_result_free(result);

        if (conn->is_admin) {
            AdminState *state = create_admin_dashboard(conn);
            gtk_main();
        } else {
            AppState *state = g_new0(AppState, 1);
            state->conn = conn;
            state->current_directory = 0;
            strcpy(state->current_path, "/");
            state->window = create_main_window(state);
            gtk_widget_show_all(state->window);
            refresh_file_list(state);
            gtk_main();
            g_free(state);
        }

        if (!g_logout_requested) break;
    }

    return 0;
}
```

---

## Appendix B: Testing Checklist

```
Login/Logout Functionality Test Plan

[ ] Test 1: Basic Logout Flow
    [ ] Login as regular user (e.g., user1)
    [ ] Verify file browser shown
    [ ] Click File > Logout
    [ ] Verify confirmation dialog shown
    [ ] Click "Yes"
    [ ] Verify login dialog shown
    [ ] Login with same credentials
    [ ] Verify file browser shown
    [ ] Verify files loaded correctly

[ ] Test 2: User Type Switching - Regular to Admin
    [ ] Login as regular user
    [ ] Logout
    [ ] Login as admin user
    [ ] Verify admin dashboard shown
    [ ] Verify user list loaded

[ ] Test 3: User Type Switching - Admin to Regular
    [ ] Login as admin user
    [ ] Logout
    [ ] Login as regular user
    [ ] Verify file browser shown

[ ] Test 4: Cancel Logout Confirmation
    [ ] Login
    [ ] Click File > Logout
    [ ] Click "No" on confirmation
    [ ] Verify window remains open
    [ ] Verify still authenticated (perform file operation)

[ ] Test 5: Cancel Re-login
    [ ] Login
    [ ] Logout and confirm
    [ ] On login dialog, click "Cancel"
    [ ] Verify application exits cleanly

[ ] Test 6: Connection Failure Handling
    [ ] Login
    [ ] Logout
    [ ] Enter invalid server address (e.g., "invalid.host")
    [ ] Click "Login"
    [ ] Verify error dialog shown
    [ ] Verify login dialog shown again
    [ ] Enter valid credentials
    [ ] Verify successful login

[ ] Test 7: Invalid Credentials Retry
    [ ] Login
    [ ] Logout
    [ ] Enter wrong password
    [ ] Click "Login"
    [ ] Verify error dialog shown
    [ ] Verify login dialog shown again
    [ ] Enter correct credentials
    [ ] Verify successful login

[ ] Test 8: Multiple Cycles
    [ ] Perform 10 consecutive logout/login cycles
    [ ] Alternate between admin and regular users
    [ ] Verify no crashes
    [ ] Verify no memory leaks (check with top or valgrind)

[ ] Test 9: Window Destroy (Quit)
    [ ] Login
    [ ] Click File > Quit
    [ ] Verify application exits
    [ ] Restart application
    [ ] Verify can login again

[ ] Test 10: Window Manager Close
    [ ] Login
    [ ] Click window X button
    [ ] Verify application exits cleanly
    [ ] Verify no error messages

[ ] Test 11: Memory Leak Validation
    [ ] Run: valgrind --leak-check=full ./gui_client
    [ ] Login
    [ ] Perform 5 logout/login cycles
    [ ] Exit application
    [ ] Check valgrind output for "definitely lost" leaks
    [ ] Verify: 0 bytes definitely lost

[ ] Test 12: UI Responsiveness
    [ ] Login
    [ ] Click logout rapidly
    [ ] Verify confirmation dialog appears
    [ ] Cancel
    [ ] Verify UI still responsive
    [ ] Perform file operations to confirm

[ ] Test 13: Admin Dashboard Logout
    [ ] Login as admin
    [ ] Verify admin dashboard shown
    [ ] Click File > Logout
    [ ] Verify confirmation dialog
    [ ] Confirm
    [ ] Verify login dialog shown
    [ ] Re-login as admin
    [ ] Verify user list reloads correctly

[ ] Test 14: Admin Dashboard Quit
    [ ] Login as admin
    [ ] Click File > Quit
    [ ] Verify application exits

[ ] Test 15: Status Bar Updates
    [ ] Login as regular user
    [ ] Verify status bar shows "Connected as user X"
    [ ] Logout
    [ ] Re-login as different user
    [ ] Verify status bar shows new user ID
```

---

## Success Criteria

Implementation is complete when:

1. ✅ Users can logout from both main window and admin dashboard
2. ✅ Login dialog shown after logout
3. ✅ Can re-login with same or different credentials
4. ✅ User type transitions work correctly (admin ↔ regular)
5. ✅ Logout confirmation dialog prevents accidental logouts
6. ✅ Canceling re-login exits application
7. ✅ No memory leaks on repeated logout/login cycles (valgrind clean)
8. ✅ All test cases pass
9. ✅ Code follows existing style and patterns
10. ✅ No regressions in existing functionality

---

## Estimated Timeline

- **Phase 1 (Login Refactoring):** 1-2 hours
- **Phase 2 (Main Window):** 1 hour
- **Phase 3 (Admin Dashboard):** 1 hour
- **Phase 4 (Main Loop):** 1-2 hours
- **Phase 5 (Admin State):** 0.5 hours
- **Phase 6 (Polish):** 0.5 hours
- **Phase 7 (Testing):** 2-3 hours
- **Phase 8 (Documentation):** 0.5 hours

**Total:** 8-12 hours

---

## Next Steps

1. Review this plan with stakeholders
2. Confirm approach and priorities
3. Begin implementation with Phase 1
4. Test each phase before proceeding
5. Conduct final integration testing
6. Deploy to production

---

**END OF PLAN**

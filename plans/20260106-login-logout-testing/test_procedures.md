# Login/Logout Functionality Test Procedures

## Test Environment
- **Server**: localhost:8080 (started)
- **GUI Client**: /Users/minhbohung111/workspace/projects/networkFinal/build/gui_client
- **Database**: fileshare.db

## Available Test Users
| Username | Password | Type | Status |
|----------|----------|------|--------|
| admin | admin | Admin | Active |
| test1 | 123456 | Regular | Active |

## Test Cases

### TC-1: Basic Login/Logout Flow (Regular User)
**Objective**: Verify regular user can login and logout successfully

**Steps**:
1. Launch GUI client: `./build/gui_client`
2. Verify login dialog appears
3. Enter credentials:
   - Server: localhost
   - Port: 8080
   - Username: test1
   - Password: 123456
4. Click "Login"
5. **Expected**: File browser window appears with title "File Sharing Client"
6. **Expected**: Menu bar shows "File" menu with "Logout" and "Quit" options
7. Click File → Logout
8. **Expected**: Confirmation dialog appears: "Are you sure you want to logout?"
9. Click "Yes"
10. **Expected**: Login dialog reappears
11. **Expected**: Previous window closes cleanly

**Pass Criteria**:
- Login successful
- File browser displays
- Logout confirmation shown
- Returns to login dialog
- No crashes or errors

---

### TC-2: Re-login After Logout (Same User)
**Objective**: Verify user can re-login after logout

**Prerequisites**: Complete TC-1

**Steps**:
1. After logout, login dialog should be visible
2. Enter same credentials (test1/123456)
3. Click "Login"
4. **Expected**: File browser window appears again
5. Verify menu and toolbar are functional
6. Click File → Logout → Yes

**Pass Criteria**:
- Re-login successful
- All UI elements functional
- No memory leaks or degraded performance

---

### TC-3: User Type Switching (Regular to Admin)
**Objective**: Verify logout allows switching between user types

**Steps**:
1. Login as test1 (regular user)
2. **Expected**: File browser window shown
3. Logout via File → Logout → Yes
4. In login dialog, change credentials:
   - Username: admin
   - Password: admin
5. Click "Login"
6. **Expected**: Admin dashboard window appears
7. **Expected**: Window title indicates admin interface
8. **Expected**: User management interface visible
9. Verify admin-specific functions available
10. Click File → Logout → Yes

**Pass Criteria**:
- Switches from file browser to admin dashboard
- Admin interface fully functional
- Proper cleanup of regular user session

---

### TC-4: User Type Switching (Admin to Regular)
**Objective**: Verify switching from admin to regular user

**Steps**:
1. Login as admin
2. **Expected**: Admin dashboard appears
3. Logout via File → Logout → Yes
4. Login as test1
5. **Expected**: File browser appears (not admin dashboard)
6. Verify no admin functions accessible

**Pass Criteria**:
- Switches from admin dashboard to file browser
- Regular user has no admin access
- Proper cleanup of admin session

---

### TC-5: Logout Cancellation
**Objective**: Verify cancel button in logout confirmation works

**Steps**:
1. Login as test1
2. Click File → Logout
3. **Expected**: Confirmation dialog appears
4. Click "No" or close dialog
5. **Expected**: Dialog closes
6. **Expected**: File browser remains open and functional
7. Verify connection still active by performing file operation
8. Now logout properly (File → Logout → Yes)

**Pass Criteria**:
- Cancel closes dialog only
- Window remains open
- Connection maintained
- Operations still work

---

### TC-6: Invalid Credentials Handling
**Objective**: Verify login retry on invalid credentials

**Steps**:
1. Launch GUI client
2. Enter invalid credentials:
   - Username: invalid
   - Password: wrong
3. Click "Login"
4. **Expected**: Error dialog: "Login failed. Invalid credentials."
5. Click OK on error dialog
6. **Expected**: Login dialog reappears for retry
7. Enter valid credentials (test1/123456)
8. Click "Login"
9. **Expected**: File browser appears

**Pass Criteria**:
- Invalid login rejected
- Error message clear
- Login dialog allows retry
- Valid login succeeds after retry

---

### TC-7: Connection Failure Handling
**Objective**: Verify handling of server connection issues

**Prerequisites**: Stop the server temporarily

**Steps**:
1. Stop server: `pkill -f "build/server"`
2. Launch GUI client
3. Attempt login with valid credentials
4. **Expected**: Error dialog: "Failed to connect to server..."
5. Click OK
6. **Expected**: Login dialog reappears
7. Restart server: `./build/server 8080 &`
8. Wait 2 seconds
9. Retry login with valid credentials
10. **Expected**: Login succeeds

**Pass Criteria**:
- Connection failure detected
- Clear error message
- Login dialog allows retry
- Reconnection works after server restart

---

### TC-8: Multiple Logout/Login Cycles
**Objective**: Verify stability over multiple sessions

**Steps**:
1. Perform 5 consecutive cycles:
   - Login as test1
   - Verify file browser appears
   - Logout
   - Login as admin
   - Verify admin dashboard appears
   - Logout
2. Monitor for memory leaks, slowdowns, crashes

**Pass Criteria**:
- All 10 logins successful
- No performance degradation
- No memory leaks
- No crashes or freezes

---

### TC-9: Window Close vs Logout
**Objective**: Verify closing window differs from logout

**Steps**:
1. Login as test1
2. Close window using X button (or window manager close)
3. **Expected**: Application exits completely
4. **Expected**: No login dialog appears
5. Restart GUI client
6. **Expected**: Fresh login dialog appears

**Pass Criteria**:
- Window close exits application
- Logout returns to login dialog
- Both cleanup connections properly

---

### TC-10: Memory and Resource Cleanup
**Objective**: Verify no memory leaks or resource issues

**Steps**:
1. Monitor client process before starting
2. Login as test1
3. Check memory usage
4. Logout
5. Check memory usage (should be similar to start)
6. Login as admin
7. Check memory usage
8. Logout
9. Check for leaked connections: `lsof -p <pid>`
10. Verify no orphaned sockets

**Pass Criteria**:
- Memory usage stable across sessions
- No leaked file descriptors
- No orphaned network connections
- Clean resource cleanup

---

## Test Execution Checklist

- [ ] TC-1: Basic Login/Logout Flow (Regular User)
- [ ] TC-2: Re-login After Logout (Same User)
- [ ] TC-3: User Type Switching (Regular to Admin)
- [ ] TC-4: User Type Switching (Admin to Regular)
- [ ] TC-5: Logout Cancellation
- [ ] TC-6: Invalid Credentials Handling
- [ ] TC-7: Connection Failure Handling
- [ ] TC-8: Multiple Logout/Login Cycles
- [ ] TC-9: Window Close vs Logout
- [ ] TC-10: Memory and Resource Cleanup

## Notes
- Execute tests in order
- Document any unexpected behavior
- Capture screenshots of errors
- Monitor server logs for issues

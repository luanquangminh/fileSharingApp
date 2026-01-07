# Manual Test Execution Checklist

**Tester**: ___________________
**Date**: ___________________
**Build**: GUI Client 115K
**Server**: localhost:8080

---

## Pre-Test Setup

- [ ] Server running on port 8080
  ```bash
  ./build/server 8080
  ```
- [ ] Test credentials verified
  - Regular: test1 / 123456
  - Admin: admin / admin
- [ ] GUI client executable present: `build/gui_client`

---

## Test Execution

### TC-1: Basic Login/Logout (Regular User)
- [ ] Launch `./build/gui_client`
- [ ] Login dialog appears
- [ ] Enter: test1 / 123456
- [ ] File browser window appears
- [ ] Menu bar shows "File" with "Logout" option
- [ ] Click File → Logout
- [ ] Confirmation dialog: "Are you sure you want to logout?"
- [ ] Click "Yes"
- [ ] Login dialog reappears
- [ ] Window closes cleanly

**Result**: [ ] PASS  [ ] FAIL
**Notes**: ___________________________________________

---

### TC-2: Re-login (Same User)
- [ ] Login with test1 / 123456 again
- [ ] File browser appears
- [ ] Menu and toolbar functional
- [ ] Logout again

**Result**: [ ] PASS  [ ] FAIL
**Notes**: ___________________________________________

---

### TC-3: User Type Switching (Regular to Admin)
- [ ] Login as test1
- [ ] File browser shown
- [ ] Logout
- [ ] Login as admin / admin
- [ ] Admin dashboard appears (different UI)
- [ ] User management interface visible
- [ ] Logout

**Result**: [ ] PASS  [ ] FAIL
**Notes**: ___________________________________________

---

### TC-4: User Type Switching (Admin to Regular)
- [ ] Login as admin
- [ ] Admin dashboard shown
- [ ] Logout
- [ ] Login as test1
- [ ] File browser shown (not admin)
- [ ] No admin functions accessible

**Result**: [ ] PASS  [ ] FAIL
**Notes**: ___________________________________________

---

### TC-5: Logout Cancellation
- [ ] Login as test1
- [ ] Click File → Logout
- [ ] Confirmation dialog appears
- [ ] Click "No" or close dialog
- [ ] Dialog closes
- [ ] Window remains open and functional
- [ ] Try file operation to verify connection
- [ ] Logout properly (Yes)

**Result**: [ ] PASS  [ ] FAIL
**Notes**: ___________________________________________

---

### TC-6: Invalid Credentials
- [ ] Launch GUI client
- [ ] Enter: invalid / wrong
- [ ] Click "Login"
- [ ] Error dialog: "Login failed. Invalid credentials."
- [ ] Click OK
- [ ] Login dialog reappears
- [ ] Enter valid credentials (test1)
- [ ] Login succeeds

**Result**: [ ] PASS  [ ] FAIL
**Notes**: ___________________________________________

---

### TC-7: Connection Failure (Optional)
**Warning**: This test stops the server temporarily

- [ ] Stop server: `pkill -f "build/server"`
- [ ] Launch GUI client
- [ ] Attempt login
- [ ] Error: "Failed to connect to server..."
- [ ] Click OK
- [ ] Restart server: `./build/server 8080 &`
- [ ] Wait 2 seconds
- [ ] Retry login
- [ ] Login succeeds

**Result**: [ ] PASS  [ ] FAIL  [ ] SKIPPED
**Notes**: ___________________________________________

---

### TC-8: Multiple Sessions (Stability)
Perform 5 complete cycles:

**Cycle 1**:
- [ ] Login as test1 → verify → logout
- [ ] Login as admin → verify → logout

**Cycle 2**:
- [ ] Login as test1 → verify → logout
- [ ] Login as admin → verify → logout

**Cycle 3**:
- [ ] Login as test1 → verify → logout
- [ ] Login as admin → verify → logout

**Cycle 4**:
- [ ] Login as test1 → verify → logout
- [ ] Login as admin → verify → logout

**Cycle 5**:
- [ ] Login as test1 → verify → logout
- [ ] Login as admin → verify → logout

**Observations**:
- [ ] No crashes
- [ ] No slowdowns
- [ ] No memory issues
- [ ] All logins successful

**Result**: [ ] PASS  [ ] FAIL
**Notes**: ___________________________________________

---

### TC-9: Window Close vs Logout
- [ ] Login as test1
- [ ] Close window with X button
- [ ] Application exits completely
- [ ] No login dialog appears
- [ ] Restart `./build/gui_client`
- [ ] Fresh login dialog appears

**Result**: [ ] PASS  [ ] FAIL
**Notes**: ___________________________________________

---

### TC-10: Memory and Resources (Optional)
**Tools**: Activity Monitor (macOS), `lsof`, or valgrind

**Before testing**:
- [ ] Note baseline memory: _________ MB

**During testing**:
- [ ] Login as test1
- [ ] Memory usage: _________ MB
- [ ] Logout
- [ ] Memory usage: _________ MB (should be similar)
- [ ] Login as admin
- [ ] Memory usage: _________ MB
- [ ] Logout
- [ ] Final memory: _________ MB

**Check for leaks**:
- [ ] `lsof -p <pid>` shows no extra sockets
- [ ] Memory stable across sessions

**Result**: [ ] PASS  [ ] FAIL  [ ] SKIPPED
**Notes**: ___________________________________________

---

## Summary

**Total Tests**: 10
**Passed**: _____
**Failed**: _____
**Skipped**: _____

**Critical Issues Found**: _____________________

**Non-Critical Issues**: _____________________

**Overall Assessment**:
- [ ] All tests passed - APPROVE FOR DEPLOYMENT
- [ ] Minor issues - FIX OPTIONAL
- [ ] Critical issues - RETURN TO DEVELOPER

---

## Screenshots / Evidence

Attach screenshots of:
- Login dialog
- File browser (regular user)
- Admin dashboard
- Logout confirmation dialog
- Error dialogs (if any)

---

## Tester Sign-off

**Name**: ___________________
**Signature**: ___________________
**Date**: ___________________

**Recommendation**:
- [ ] APPROVED for deployment
- [ ] APPROVED with minor fixes
- [ ] REJECTED - critical issues found

---

**Notes**:

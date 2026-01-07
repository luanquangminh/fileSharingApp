#!/bin/bash
# Validation script for login/logout implementation
# Checks code structure, compilation, and basic functionality

PROJECT_ROOT="/Users/minhbohung111/workspace/projects/networkFinal"
cd "$PROJECT_ROOT"

echo "==================================================================="
echo "Login/Logout Implementation Validation"
echo "==================================================================="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass_count=0
fail_count=0

function test_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((pass_count++))
}

function test_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((fail_count++))
}

function test_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo "1. Code Structure Validation"
echo "-------------------------------------------------------------------"

# Check LoginResult struct exists
if grep -q "LoginResult" src/client/gui/gui.h; then
    test_pass "LoginResult struct defined in gui.h"
else
    test_fail "LoginResult struct not found in gui.h"
fi

# Check perform_login function
if grep -q "LoginResult\* perform_login" src/client/gui/gui.h; then
    test_pass "perform_login() function declared"
else
    test_fail "perform_login() not declared in gui.h"
fi

# Check global logout flag
if grep -q "g_logout_requested" src/client/gui/main.c; then
    test_pass "Global logout flag (g_logout_requested) found"
else
    test_fail "Global logout flag not found"
fi

# Check login loop in main.c
if grep -q "while (1)" src/client/gui/main.c && grep -q "g_logout_requested" src/client/gui/main.c; then
    test_pass "Login loop implemented in main.c"
else
    test_fail "Login loop not properly implemented"
fi

# Check logout handlers in main_window.c
if grep -q "on_logout_activate" src/client/gui/main_window.c; then
    test_pass "Logout handler in main_window.c"
else
    test_fail "Logout handler missing in main_window.c"
fi

# Check logout handlers in admin_dashboard.c
if grep -q "on_logout_activate" src/client/gui/admin_dashboard.c; then
    test_pass "Logout handler in admin_dashboard.c"
else
    test_fail "Logout handler missing in admin_dashboard.c"
fi

# Check confirmation dialog
if grep -q "Are you sure you want to logout" src/client/gui/main_window.c; then
    test_pass "Logout confirmation dialog in main_window.c"
else
    test_fail "Logout confirmation dialog not found"
fi

if grep -q "Are you sure you want to logout" src/client/gui/admin_dashboard.c; then
    test_pass "Logout confirmation dialog in admin_dashboard.c"
else
    test_fail "Logout confirmation dialog not found"
fi

# Check connection cleanup
if grep -q "client_disconnect" src/client/gui/main_window.c && \
   grep -q "g_logout_requested = TRUE" src/client/gui/main_window.c; then
    test_pass "Connection cleanup on logout in main_window.c"
else
    test_fail "Connection cleanup not properly implemented"
fi

echo ""
echo "2. Compilation Check"
echo "-------------------------------------------------------------------"

# Clean and rebuild
echo "Cleaning previous build..."
make clean > /dev/null 2>&1 || true

echo "Building GUI client..."
if make gui > build.log 2>&1; then
    test_pass "GUI client compiles successfully"

    # Check for warnings
    warning_count=$(grep -i "warning:" build.log | wc -l | tr -d ' ')
    if [ "$warning_count" -eq "0" ]; then
        test_pass "No compilation warnings"
    else
        test_warn "Compilation warnings found: $warning_count"
        echo "    See build.log for details"
    fi
else
    test_fail "GUI client compilation failed"
    echo "    Check build.log for errors"
fi

# Check executable exists
if [ -f "build/gui_client" ]; then
    test_pass "GUI client executable created"
    ls -lh build/gui_client | awk '{print "    Size: " $5}'
else
    test_fail "GUI client executable not found"
fi

echo ""
echo "3. Server Status Check"
echo "-------------------------------------------------------------------"

# Check if server is running
if netstat -an | grep -q "8080.*LISTEN"; then
    test_pass "Server is running on port 8080"
else
    test_warn "Server is not running on port 8080"
    echo "    Start server with: ./build/server 8080"
fi

# Check server executable
if [ -f "build/server" ]; then
    test_pass "Server executable exists"
else
    test_fail "Server executable not found"
fi

echo ""
echo "4. Database Validation"
echo "-------------------------------------------------------------------"

# Check database exists
if [ -f "fileshare.db" ]; then
    test_pass "Database file exists"
else
    test_fail "Database file not found"
fi

# Check test users
user_count=$(sqlite3 fileshare.db "SELECT COUNT(*) FROM users WHERE is_active=1;" 2>/dev/null || echo "0")
if [ "$user_count" -ge "2" ]; then
    test_pass "Test users available: $user_count"
    sqlite3 fileshare.db "SELECT '    ' || username || ' (admin=' || is_admin || ')' FROM users WHERE is_active=1;"
else
    test_warn "Insufficient test users (found: $user_count, need: 2+)"
fi

echo ""
echo "5. Code Quality Checks"
echo "-------------------------------------------------------------------"

# Check for memory leaks patterns
if grep -q "g_free" src/client/gui/login_dialog.c; then
    test_pass "Memory cleanup functions used (g_free)"
else
    test_warn "No g_free calls found in login_dialog.c"
fi

# Check for null pointer checks
if grep -q "if.*!.*conn" src/client/gui/main.c; then
    test_pass "Null pointer checks present"
else
    test_warn "Null pointer checks may be insufficient"
fi

# Check for proper GTK cleanup
if grep -q "gtk_widget_destroy" src/client/gui/login_dialog.c; then
    test_pass "GTK widget cleanup (gtk_widget_destroy)"
else
    test_warn "GTK widget cleanup may be missing"
fi

echo ""
echo "6. Function Signature Validation"
echo "-------------------------------------------------------------------"

# Verify function signatures match between .h and .c files
if grep -q "LoginResult\* perform_login(GtkWidget \*parent_window)" src/client/gui/login_dialog.c; then
    test_pass "perform_login() signature correct"
else
    test_warn "perform_login() signature mismatch"
fi

if grep -q "void login_result_free(LoginResult \*result)" src/client/gui/login_dialog.c; then
    test_pass "login_result_free() implemented"
else
    test_fail "login_result_free() not found"
fi

echo ""
echo "==================================================================="
echo "Validation Summary"
echo "==================================================================="
echo -e "${GREEN}Passed:${NC} $pass_count"
echo -e "${RED}Failed:${NC} $fail_count"
echo ""

if [ $fail_count -eq 0 ]; then
    echo -e "${GREEN}✓ All critical validations passed${NC}"
    echo ""
    echo "Next Steps:"
    echo "1. Ensure server is running: ./build/server 8080"
    echo "2. Run GUI client: ./build/gui_client"
    echo "3. Execute manual test cases from test_procedures.md"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some validations failed${NC}"
    echo ""
    echo "Please fix the failed checks before testing."
    exit 1
fi

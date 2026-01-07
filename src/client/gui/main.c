#include "gui.h"
#include "admin_dashboard.h"
#include "../net_handler.h"
#include <stdlib.h>
#include <string.h>

// Global flag to distinguish logout from quit
gboolean g_logout_requested = FALSE;

int main(int argc, char *argv[]) {
    gtk_init(&argc, &argv);

    // Main login loop - allows logout and re-login
    while (1) {
        g_logout_requested = FALSE;  // Reset flag

        // Show login dialog
        LoginResult *login_result = perform_login(NULL);

        // Check if user cancelled
        if (login_result->is_cancelled || !login_result->conn) {
            login_result_free(login_result);
            break;  // Exit application
        }

        ClientConnection *conn = login_result->conn;
        login_result_free(login_result);

        // Route based on user type
        if (conn->is_admin) {
            // Admin dashboard
            create_admin_dashboard(conn);
            gtk_main();  // Blocks until logout or quit
        } else {
            // Regular user file browser
            AppState *state = g_new0(AppState, 1);
            state->conn = conn;
            state->current_directory = 0;
            strcpy(state->current_path, "/");

            state->window = create_main_window(state);
            gtk_widget_show_all(state->window);
            refresh_file_list(state);

            gtk_main();  // Blocks until logout or quit

            // Cleanup state (connection freed in handlers)
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

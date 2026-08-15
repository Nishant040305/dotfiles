// Authorize the proxyredsocks script execution without password prompt
polkit.addRule(function(action, subject) {
    if (
        action.id == "org.freedesktop.policykit.exec" &&
        subject.active === true &&                                  // User has active session
        subject.local === true                                      // Local sesstion (not remote SSH)
    ) {
        var cmd = action.lookup("command_line");
        if (
            cmd == "/usr/local/sbin/masquerade" ||
            cmd.startsWith("/usr/local/sbin/masquerade ")
        ) {
            return polkit.Result.YES;                               // Allow without authentication
        }
    }
});

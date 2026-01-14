// =============================================================================
// PolicyKit Authorization Rule for Redsocks Proxy Management
// =============================================================================
// File Location: /etc/polkit-1/rules.d/90-proxyredsocks.rules
//
// Purpose:
//   Allows non-root users to execute the proxyredsocks script without entering
//   a password. The script itself still requires root privileges through sudo.
//
// Installation:
//   sudo install -m 644 -o root -g root ~/.dotfiles/misc/90-proxyredsocks.rules.js /etc/polkit-1/rules.d/90-proxyredsocks.rules
//   sudo systemctl restart polkit
//
// Verification:
//   polkit-rule-graphical  # GUI tool to verify rules
//   or check: ls -la /etc/polkit-1/rules.d/
//
// Security Notes:
//   - Rule is restricted to local sessions (subject.local === true)
//   - Rule only applies when user is actively logged in (subject.active === true)
//   - Only the /usr/local/sbin/proxyredsocks program is authorized
// =============================================================================

polkit.addRule(function (action, subject) {
  // Authorize the proxyredsocks script execution without password prompt
  if (
    action.id == "org.freedesktop.policykit.exec" &&
    action.lookup("program") == "/usr/local/sbin/proxyredsocks" &&
    subject.active === true && // User has active session
    subject.local === true // Local session (not remote SSH)
  ) {
    return polkit.Result.YES; // Allow without authentication
  }
});

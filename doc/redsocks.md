# Proxy Utility - Redsocks

This module provides a transparent proxy redirection utility built around **redsocks**, allowing system-wide traffic to be routed through a proxy without per-application configuration.

The [redsocks binary](../proxy/bin/redsocks2) used is `redsocks2` built from [semigodking/redsocks](https://github.com/semigodking/redsocks) for Fedora 43.

The [polkat helper script](../proxy/90-proxyredsocks.rules.js) is to integrate with the [Custom Command Toggle GNOME extension](https://extensions.gnome.org/extension/7012/custom-command-toggle/) as redsocks typically requires administrator privileges. Configure the extension to call the script with `enable`, `disable`, or `status` arguments.

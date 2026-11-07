// Shared by QML and portable regression tests. No machine-specific commands.
function commandFor(app, directory, preference) {
    const command = app.command || [];
    const legacy = command.length === 2 &&
        String(command[0]).split("/").pop() === "launchpad" &&
        ["toggle", "show", "open"].indexOf(command[1]) !== -1;
    const defaultMenu = app.shellPlugin === "omarchy.menu" &&
        (!app.payload || app.payload.initialMenu === "apps");
    const applications = app.launcher === true || legacy ||
        (["launcher", "launchpad"].indexOf(app.key) !== -1 &&
         (defaultMenu || (!app.command && !app.shellPlugin)));
    const explicitLaunchpad = app.shellPlugin === "okuma.dev_launchpad4omarchy";
    if (!applications && !explicitLaunchpad) return null;
    const plugin = explicitLaunchpad ? app.shellPlugin : (preference || "auto");
    return ["python3", directory + "activate-launcher.py", "--plugin", plugin];
}

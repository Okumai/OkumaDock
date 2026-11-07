// Shared by QML and portable regression tests. No machine-specific commands.
function commandFor(app, directory, preference) {
    const command = app.command || [];
    const legacy = command.length === 2 &&
        String(command[0]).split("/").pop() === "launchpad" &&
        ["toggle", "show", "open"].indexOf(command[1]) !== -1;
    const appsPayload = app.payload &&
        (app.payload.initialMenu === "apps" || app.payload.menu === "apps");
    const defaultMenu = app.shellPlugin === "omarchy.menu" && (!app.payload || appsPayload);
    const builtInApps = command.length === 3 && command[0] === "omarchy-shell" &&
        command[1] === "omarchy.dock" && command[2] === "apps";
    const applications = app.launcher === true || legacy || builtInApps ||
        (app.shellPlugin === "omarchy.menu" && appsPayload) ||
        (["launcher", "launchpad"].indexOf(app.key) !== -1 &&
         (defaultMenu || (!app.command && !app.shellPlugin)));
    const explicitLaunchpad = app.shellPlugin === "okuma.dev_launchpad4omarchy";
    if (!applications && !explicitLaunchpad) return null;
    const plugin = explicitLaunchpad ? app.shellPlugin : (preference || "auto");
    return ["python3", directory + "activate-launcher.py", "--plugin", plugin];
}

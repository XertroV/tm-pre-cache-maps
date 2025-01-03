const string PluginName = Meta::ExecutingPlugin().Name;
const string MenuIconColor = "\\$f5d";
const string PluginIcon = Icons::Cogs;
const string MenuTitle = MenuIconColor + PluginIcon + "\\$z " + PluginName;

void Main() {
    startnew(AfterScripts_Coro).WithRunContext(Meta::RunContext::AfterScripts);
    InterceptProcs();
    auto app = cast<CTrackMania>(GetApp());
    while (true) {
        RunWhileNotInServer(app);
        RunWhileInServer(app);
        yield();
    }
    error("Main loop exited. This should not happen.");
}

/** Called when the plugin is unloaded and completely removed from memory.
*/
void OnDestroyed() {
    MLHook::UnregisterMLHooksAndRemoveInjectedML();
}

void AfterScripts_Coro() {
    Init_MLHook();
    // yield();
    // while (true) {
    //     H_ReceiveMapUids.ProcessMsgs();
    //     yield();
    // }
}

void RunWhileNotInServer(CTrackMania@ app) {
    auto si = cast<CTrackManiaNetworkServerInfo>(app.Network.ServerInfo);
    while (si.ServerLogin == "") {
        yield(10);
    }
}


void RunWhileInServer(CTrackMania@ app) {
    yield(10);
    sleep(2000);
    yield(10);
    while (app.RootMap is null) yield();
    if (app.Network.PlaygroundClientScriptAPI is null) return;
    auto si = cast<CTrackManiaNetworkServerInfo>(app.Network.ServerInfo);
    if (si.ServerLogin.Length > 0) {
        dev_print("RunWhileInServer starting: ServerLogin: " + si.ServerLogin);
    }
    while (si.ServerLogin != "" && app.Network.PlaygroundClientScriptAPI !is null) {
        try {
            MaybeCheckForNewMaps(app); // cast<CTrackManiaNetwork>(app.Network)
        } catch {
            warn("RunWhileInServer: Exception: " + getExceptionInfo());
        }
        yield(10);
    }
    dev_print("RunWhileInServer exiting: ServerLogin: " + si.ServerLogin);
}

void MaybeCheckForNewMaps(CTrackMania@ app) { // CTrackManiaNetwork@ net) {
    // auto pgsApi = app.Network.PlaygroundClientScriptAPI;
    // if (pgsApi is null) return;
    // trace('checking MapList_IsInProgress');
    if (H_ReceiveMapUids.MapList_IsInProgress) return;
    // trace('checking MapList_IsInProgress = false');
    if (CheckLimit::ShouldCheckForNewMaps(app)) {
        trace('ShouldCheckForNewMaps = true');
        CheckForNewMapsNow(app);
    }
}

void CheckForNewMapsNow(CTrackMania@ app) {
    auto si = cast<CTrackManiaNetworkServerInfo>(app.Network.ServerInfo);
    if (si.ServerLogin.Length == 0) return;

    trace('CheckForNewMapsNow: checking MapList_IsInProgress');
    // auto pgsApi = app.Network.PlaygroundClientScriptAPI;
    if (H_ReceiveMapUids.MapList_IsInProgress) return;

    trace('CheckForNewMapsNow: calling StartRequest');
    CheckLimit::StartRequest(); // calls pgsApi.MapList_Request();
    trace('CheckForNewMapsNow: called StartRequest');
    // pgsApi 0x000001d9da725500
    // accessing this at the wrong time can crash the game maybe?
    trace('CheckForNewMapsNow: checking pgsApi.MapList_IsInProgress again');
    if (!H_ReceiveMapUids.MapList_IsInProgress) {
        warn("MapList_IsInProgress did not immediately update");
    }
    trace('CheckForNewMapsNow: waiting for MapList_IsInProgress to be false');
    while (H_ReceiveMapUids.MapList_IsInProgress) {
        yield();
    }
    if (app.Network.PlaygroundClientScriptAPI is null) {
        warn("CheckForNewMapsNow: pgsApi is null");
        return;
    }
    trace('CheckForNewMapsNow: MapList_IsInProgress is false');
    if (H_ReceiveMapUids.MapList_MapUids.Length != H_ReceiveMapUids.MapList_Names.Length) {
        warn("MapList_MapUids.Length != MapList_Names.Length: " + H_ReceiveMapUids.MapList_MapUids.Length + " != " + H_ReceiveMapUids.MapList_Names.Length);
    }
    int nbMaps = Math::Min(int(H_ReceiveMapUids.MapList_MapUids.Length), H_ReceiveMapUids.MapList_Names.Length);
    trace('CheckForNewMapsNow: nbMaps: ' + nbMaps);
    for (int i = 0; i < nbMaps; i++) {
        // auto uid = pgsApi.MapList_MapUids[i];
        // auto name = pgsApi.MapList_Names[i];
        // print("Map: " + uid + " - " + name);
        trace('CheckForNewMapsNow: calling PreCacher::CheckAndCacheMapIfNew_Async');
        PreCacher::CheckAndCacheMapIfNew_Async(H_ReceiveMapUids.MapList_MapUids[i], H_ReceiveMapUids.MapList_Names[i]);
        // pgsApi.MapList_MapUids
    }
}


namespace CheckLimit {
    uint64 lastMapsCheck = 0;

    void StartRequest() {
        H_ReceiveMapUids.MapList_Request();
        lastMapsCheck = Time::Now;
        dev_print("MapList_Request() called at " + lastMapsCheck);
    }

    bool ShouldCheckForNewMaps(CTrackMania@ app) {
        auto sinceLastCheck = Time::Now - lastMapsCheck;
        auto gt30sSinceLastCheck = sinceLastCheck > 30000;
        auto gt4sSinceLastCheck = sinceLastCheck > 4000;
        return gt30sSinceLastCheck // more than 30s since last check
            // faster refresh periods
            || (gt4sSinceLastCheck && (
                // less than 20s remaining in the current map
                IsModeTimeRemainingLt(app, 20000)
                // or sequence is podium, ui interaction
                || UISeqOkayForMapsRefresh(app)
            ));
    }

    bool UISeqOkayForMapsRefresh(CTrackMania@ app) {
        try {
            auto pgApp = app.Network.ClientManiaAppPlayground;
            if (pgApp is null) return false;
            auto seq = pgApp.UI.UISequence;
            return seq == CGamePlaygroundUIConfig::EUISequence::Podium
                || seq == CGamePlaygroundUIConfig::EUISequence::UIInteraction;
        } catch {}
        return false;
    }
}









// returns false if invalid time left
bool IsModeTimeRemainingLt(CTrackMania@ app, int millis) {
    auto timeLeft = GetModeTimeRemaining(app);
    return timeLeft >= 0 && timeLeft < millis;
}

int GetModeTimeRemaining(CTrackMania@ app) {
    auto gt = GetGameTime(app.Network.PlaygroundClientScriptAPI);
    auto startEnd = GetRulesStartEndTime(cast<CSmArenaClient>(app.CurrentPlayground));
    if (gt <= -1 || startEnd.x <= -1 || startEnd.y <= -1) return -1;
    return startEnd.y - gt;
}

int GetServerTimeElapsed(CTrackMania@ app) {
    auto gt = GetGameTime(app.Network.PlaygroundClientScriptAPI);
    auto startEnd = GetRulesStartEndTime(cast<CSmArenaClient>(app.CurrentPlayground));
    if (gt == -1 || startEnd.x == -1 || startEnd.y == -1) return -1;
    return gt - startEnd.x;
}

int GetGameTime(CGamePlaygroundClientScriptAPI@ pgsApi = null) {
    if (pgsApi is null) {
        auto app = cast<CTrackMania>(GetApp());
        if (app.Network.PlaygroundClientScriptAPI is null) return -1;
        @pgsApi = app.Network.PlaygroundClientScriptAPI;
    }
    return pgsApi.GameTime;
}

int2 GetRulesStartEndTime(CSmArenaClient@ currPlayground = null) {
    if (currPlayground is null) {
        @currPlayground = cast<CSmArenaClient>(GetApp().CurrentPlayground);
    }
    try {
        return int2(currPlayground.Arena.Rules.RulesStateStartTime, currPlayground.Arena.Rules.RulesStateEndTime);
    } catch {}
    return int2(-1, -1);
}

void dev_print(const string &in msg) {
#if DEV
    print(msg);
#endif
}

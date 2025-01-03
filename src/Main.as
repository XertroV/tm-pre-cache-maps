const string PluginName = Meta::ExecutingPlugin().Name;
const string MenuIconColor = "\\$f5d";
const string PluginIcon = Icons::Cogs;
const string MenuTitle = MenuIconColor + PluginIcon + "\\$z " + PluginName;

void Main() {
#if DEV
    InterceptProcs();
#endif
    auto app = cast<CTrackMania>(GetApp());
    while (true) {
        RunWhileNotInServer(app);
        RunWhileInServer(app);
        yield();
    }
    error("Main loop exited. This should not happen.");
}

void RunWhileNotInServer(CTrackMania@ app) {
    auto si = cast<CTrackManiaNetworkServerInfo>(app.Network.ServerInfo);
    while (si.ServerLogin == "") {
        yield(10);
    }
}


void RunWhileInServer(CTrackMania@ app) {
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

void MaybeCheckForNewMaps(CTrackMania@ app) {
    if (MLFeed::Get_MapListUids_Receiver().MapList_IsInProgress) return;
    // trace('checking MapList_IsInProgress = false');
    if (CheckLimit::ShouldCheckForNewMaps(app)) {
        trace('ShouldCheckForNewMaps = true');
        CheckForNewMapsNow(app);
    }
}

void CheckForNewMapsNow(CTrackMania@ app) {
    auto si = cast<CTrackManiaNetworkServerInfo>(app.Network.ServerInfo);
    if (si.ServerLogin.Length == 0) return;

    auto listUids = MLFeed::Get_MapListUids_Receiver();
    if (listUids.MapList_IsInProgress) return;

    CheckLimit::StartRequest();
    if (!listUids.MapList_IsInProgress) {
        warn("MapList_IsInProgress did not immediately update");
    }
    while (listUids.MapList_IsInProgress) {
        yield();
    }
    auto @uids = listUids.MapList_MapUids;
    auto @names = listUids.MapList_Names;
    // trace('CheckForNewMapsNow: MapList_IsInProgress is false');
    if (uids.Length != names.Length) {
        warn("MapList_MapUids.Length != MapList_Names.Length: " + uids.Length + " != " + names.Length);
    }
    int nbMaps = Math::Min(int(uids.Length), names.Length);
    // trace('CheckForNewMapsNow: nbMaps: ' + nbMaps);
    for (int i = 0; i < nbMaps; i++) {
        // trace('CheckForNewMapsNow: calling PreCacher::CheckAndCacheMapIfNew_Async');
        PreCacher::CheckAndCacheMapIfNew_Async(uids[i], names[i]);
    }
}


namespace CheckLimit {
    uint64 lastMapsCheck = 0;

    void StartRequest() {
        MLFeed::Get_MapListUids_Receiver().MapList_Request();
    }

    bool ShouldCheckForNewMaps(CTrackMania@ app) {
        auto sinceLastCheck = MLFeed::Get_MapListUids_Receiver().MsSinceLastReqStart;
        auto gt30sSinceLastCheck = sinceLastCheck > 30000;
        auto gt2sSinceLastCheck = sinceLastCheck > 2000;
        return gt30sSinceLastCheck // more than 30s since last check
            // faster refresh periods
            || (gt2sSinceLastCheck && (
                // less than 20s remaining in the current map
                MLFeed::GetRaceData_V4().IsRemainingRulesTimeLessThan(20000)
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

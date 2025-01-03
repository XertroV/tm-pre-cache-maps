const string PluginName = Meta::ExecutingPlugin().Name;
const string MenuIconColor = "\\$f5d";
const string PluginIcon = Icons::Cogs;
const string MenuTitle = MenuIconColor + PluginIcon + "\\$z " + PluginName;

void Main() {
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

uint lastUpdateNonce = 0;

void MaybeCheckForNewMaps(CTrackMania@ app) {
    auto listUids = MLFeed::Get_MapListUids_Receiver();
    if (listUids.MapList_IsInProgress) return;
    // trace('checking MapList_IsInProgress = false');
    if (CheckLimit::ShouldCheckForNewMaps(app)) {
        trace('ShouldCheckForNewMaps = true');
        CheckForNewMapsNow(app);
    } else if (lastUpdateNonce != listUids.UpdateCount && !listUids.MapList_IsInProgress) {
        OnOutOfCycleUpdate();
    }
    lastUpdateNonce = listUids.UpdateCount;
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
    PopulateUidsFromSource(listUids);
}

void OnOutOfCycleUpdate() {
    PopulateUidsFromSource(MLFeed::Get_MapListUids_Receiver());
}

const int MAX_MAPS_TO_CACHE = 3;

void PopulateUidsFromSource(MLFeed::MapListUids_Receiver@ listUids) {
    auto @uids = listUids.MapList_MapUids;
    auto @names = listUids.MapList_Names;
    int nbMaps = int(uids.Length);
    // trace('CheckForNewMapsNow: nbMaps: ' + nbMaps);
    Meta::PluginCoroutine@[] coros;

    int startIx = uids.Find(MLFeed::GetRaceData_V4().Map) + 1;
    int endIx = startIx + Math::Min(MAX_MAPS_TO_CACHE, nbMaps);
    trace('PopulateUidsFromSource: startIx: ' + startIx + ' endIx: ' + endIx + ' nbMaps: ' + nbMaps + ', e-s=n? ' + (endIx - startIx) + '==' + Math::Min(nbMaps, MAX_MAPS_TO_CACHE));

    for (int i = startIx; i < endIx; i++) {
        // running them as coros ensures we copy all relevant data immediately.
        coros.InsertLast(startnew(Run_CheckAndCacheMapIfNew_Coro, UidAndName(uids[i % nbMaps], names[i % nbMaps])));
        trace('PopulateUidsFromSource: ' + uids[i % nbMaps] + ' - ' + names[i % nbMaps]);
    }
    await(coros);
}

void Run_CheckAndCacheMapIfNew_Coro(ref@ ref) {
    auto @uidAndName = cast<UidAndName>(ref);
    PreCacher::CheckAndCacheMapIfNew_Async(uidAndName.Uid, uidAndName.Name);
}

class UidAndName {
    string Uid;
    string Name;
    UidAndName(const string &in uid, const string &in name) {
        Uid = uid;
        Name = name;
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


void dev_print(const string &in msg) {
#if DEV
    print(msg);
#endif
}

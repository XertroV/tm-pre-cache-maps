#if SIG_DEVELOPER

string lastUidFromMlExec = "";

uint patchedAt = 0;

void RenderEarly() {
    return;
    if (UI::Begin("Server Map Reqs Debug")) {

        // UI::BeginDisabled(Time::Now - patchedAt < 5000);
        // if (UI::Button("Patch Pause Menu ML")) {
        //     RunPauseMenuMLPatch();
        // }
        // UI::EndDisabled();

        auto listUids = MLFeed::Get_MapListUids_Receiver();

        auto app = cast<CTrackMania>(GetApp());
        auto si = cast<CTrackManiaNetworkServerInfo>(app.Network.ServerInfo);
        UI::Text("ServerLogin: " + si.ServerLogin);
        // UI::Text("ChallengeIds.Length: " + si.ChallengeIds.Length);
        // UI::Text("ChallengeNames.Length: " + si.ChallengeNames.Length);
        UI::Text("MapList_IsInProgress: " + listUids.MapList_IsInProgress);

        if (UI::Button("Request Map List")) {
            listUids.MapList_Request();
        }

        UI::Text("MapList_MapUids.Length: " + listUids.MapList_MapUids.Length);
        UI::Indent();
        for (uint i = 0; i < listUids.MapList_MapUids.Length; i++) {
            UI::Text(tostring(i + 1) + ": " + listUids.MapList_MapUids[i]);
        }
        UI::Unindent();
        UI::Text("MapList_Names.Length: " + listUids.MapList_Names.Length);
        UI::Indent();
        for (uint i = 0; i < listUids.MapList_Names.Length; i++) {
            UI::Text(tostring(i + 1) + ": " + listUids.MapList_Names[i]);
        }
        UI::Unindent();

    }
    UI::End();
}



void RunPauseMenuMLPatch() {
    auto app = GetApp();
    auto cmap = app.Network.ClientManiaAppPlayground;
    for (uint i = 0; i < cmap.UILayers.Length; i++) {
        if (IsPauseMenuLayer(cmap.UILayers[i])) {
            // RunPatchMenuLayerOn(cmap.UILayers[i]);
            break;
        }
    }
    print("RunPauseMenuMLPatch: Patched at " + Time::Now);
    patchedAt = Time::Now;
}

bool IsPauseMenuLayer(CGameUILayer@ layer) {
    return layer.ManialinkPageUtf8.StartsWith("\n<manialink name=\"UIModule_Online_PauseMenu\"");
}

// void RunPatchMenuLayerOn(CGameUILayer@ layer) {
//     auto ml = layer.ManialinkPageUtf8;
//     ml = ml.Replace("Name = Playground.MapList_Names[Index],\n								AuthorDisplayName = \"\",",
//                "Name = \"Uid: \"^MapUid,\n								AuthorDisplayName = Playground.MapList_Names[Index],");
//     print("RunPatchMenuLayerOn: About to apply patched");
//     layer.ManialinkPageUtf8 = ml;
//     print("RunPatchMenuLayerOn: Patched");
// }

#endif

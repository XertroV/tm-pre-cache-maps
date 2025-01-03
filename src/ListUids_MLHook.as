void Init_MLHook() {
    MLHook::RegisterMLHook(H_ReceiveMapUids, "ListUids_Pair");
    MLHook::RegisterMLHook(H_ReceiveMapUids, "ListUids_Clear");
    MLHook::RegisterMLHook(H_ReceiveMapUids, "ListUids_IsReqActive");
}

ListUids_MLHook@ H_ReceiveMapUids = ListUids_MLHook();

class ListUids_MLHook : MLHook::HookMLEventsByType {
    MLHook::PendingEvent@[] incoming_msgs;
    uint UpdateCount = 0;

    string[] MapList_MapUids;
    string[] MapList_Names;
    bool MapList_IsInProgress;

    uint64 lastCheckStart = 0;
    uint64 lastCheckEnd = 0;

    ListUids_MLHook() {
        super("ListUids");
        startnew(CoroutineFunc(this._RegisterManialinkToInject));
    }

    uint64 get_MsSinceLastReqStart() {
        return Time::Now - lastCheckStart;
    }

    uint64 get_MsSinceLastReqEnd() {
        return Time::Now - lastCheckEnd;
    }

    private void _RegisterManialinkToInject() {
        MLHook::InjectManialinkToPlayground("ListUids", Get_ListUids_Script_txt_Content(), true);
    }

    void OnEvent(MLHook::PendingEvent@ event) override {
        // incoming_msgs.InsertLast(event);
        ProcessMsg(event);
    }

    void MapList_Request() {
        if (MapList_IsInProgress) {
            warn("MapList_Request: already in progress");
            return;
        }
        SendListRequestToML();
        MapList_IsInProgress = true;
        lastCheckStart = Time::Now;
    }

    protected void SendListRequestToML() {
        MLHook::Queue_MessageManialinkPlayground("ListUids", {});
    }

    // void ProcessMsgs() {
    //     if (incoming_msgs.Length == 0) return;
    //     for (uint i = 0; i < incoming_msgs.Length; i++) {
    //         ProcessMsg(incoming_msgs[i]);
    //     }
    //     incoming_msgs.RemoveRange(0, incoming_msgs.Length);
    // }

    protected void ProcessMsg(MLHook::PendingEvent@ event) {
        string ty = event.type.SubStr(22); // remove MLHook_Event_ListUids_
        if (ty == "Pair") {
            if (event.data.Length != 2) {
                warn("ListUids_Pair: expected 2 data elements, got " + event.data.Length);
                return;
            }
            auto uid = string(event.data[0]);
            auto name = string(event.data[1]);
            RegisterUid(uid, name);
            UpdateCount++;
            // trace("Pair: " + uid + " - " + name);
        } else if (ty == "Clear") {
            ClearKnownUids();
            UpdateCount++;
            // trace("ClearKnownUids");
        } else if (ty == "IsReqActive") {
            MapList_IsInProgress = event.data.Length > 0 && string(event.data[0]).ToLower() == "true";
            UpdateCount++;
            lastCheckEnd = Time::Now;
            // trace("IsReqActive set MapList_IsInProgress: " + MapList_IsInProgress);
        } else {
            warn("ListUids_MLHook: unknown event type: " + ty + " - " + event.type);
        }
    }

    protected void RegisterUid(const string &in uid, const string &in name) {
        if (MapList_MapUids.Find(uid) != -1) {
            warn("ListUids_MLHook: uid already registered: " + uid + " - " + name);
            return;
        }
        MapList_MapUids.InsertLast(uid);
        MapList_Names.InsertLast(name);
    }

    protected void ClearKnownUids() {
        MapList_MapUids.RemoveRange(0, MapList_MapUids.Length);
        MapList_Names.RemoveRange(0, MapList_Names.Length);
    }
}
// MLHook::Queue_MessageManialinkPlayground

void InterceptProcs() {
    // Dev::InterceptProc("CGamePlaygroundClientScriptAPI", "MapList_Request", CGamePlaygroundClientScriptAPI_MapList_Request);
}

bool CGamePlaygroundClientScriptAPI_MapList_Request(CMwStack &in stack, CMwNod@ nod) {
    warn("          !!!!!!!!!!!!!!!!!           CGamePlaygroundClientScriptAPI::MapList_Request");
    return true;
}

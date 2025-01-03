namespace Core {
    string GetMapUrl(const string &in uid) {
        auto menuApp = cast<CTrackMania>(GetApp()).MenuManager.MenuCustom_CurrentManiaApp;
        auto req = menuApp.DataFileMgr.Map_NadeoServices_GetFromUid(menuApp.UserMgr.Users[0].Id, uid);
        while (req.IsProcessing) yield();
        if (req.HasSucceeded) {
            string url = req.Map.FileUrl;
            menuApp.DataFileMgr.TaskResult_Release(req.Id);
            @req = null;
            return url;
        }
        if (req.IsCanceled) {
            warn("Core::GetMapUrl: Request canceled");
            return "";
        }
        if (!req.HasFailed) throw("Request did not fail, but did not succeed either");
        warn("Core::GetMapUrl: Request failed: Ty = " + req.ErrorType + "; Code = " + req.ErrorCode + "; Desc = " + req.ErrorDescription);
        menuApp.DataFileMgr.TaskResult_Release(req.Id);
        return "";
    }
}

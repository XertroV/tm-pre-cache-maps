namespace PreCacher {
    // keeps track of uids and urls we have already seen
    dictionary seenThings;

    // this retrieves a map url from nadeo and precaches it. safe to call more than once with the same UID (does nothing 2nd+ time). Will yield.
    void CheckAndCacheMapIfNew_Async(const string &in uid, const string &in name = "<Unk Name>") {
        auto uidLen = uid.Length;

        if (seenThings.Exists(uid)) return;
        seenThings[uid] = true;
        trace("PreCacher: Caching map: " + uid + " - " + name);
        string url = Core::GetMapUrl(uid);
        if (url == "") {
            warn("PreCacher: Could not get map url for " + uid + " - " + name);
            return;
        }
        PreCacher::PreCacheAsset(url);
    }

    // use this to precache maps or other assets. safe to call more than once with the same URL (prints log 2nd+ time).
    void PreCacheAsset(const string &in url) {
#if DEPENDENCY_BETTERROOMMANAGER
        // If BRM is installed, defer to it to avoid accidentally requesting same url more than once
        BRM::PreCacheMap(url);
#else
        // otherwise, replicate the BRM logic here
        if (seenThings.Exists(url)) {
            trace("PreCacher::PreCacheAsset: Already pre-cached: " + url);
            return;
        }
        seenThings[url] = true;
        auto audio = cast<CTrackMania>(GetApp()).MenuManager.MenuCustom_CurrentManiaApp.Audio;
        auto sound = audio.CreateSound(url);
        // clean up the sound to avoid polluting the audio engine
        if (sound is null) {
            error("PreCacher::PreCacheAsset: Null response trying to pre-cache: " + url);
            PCM_PleaseReportError();
        } else {
            audio.DestroySound(sound);
        }
#endif
    }
}

void PCM_PleaseReportError() {
    warn("PreCacher::PreCacheMap: Please report this to @XertroV in the openplanet discord: https://openplanet.dev/link/discord ; https://discord.com/channels/276076890714800129/1063781798104010772");
}

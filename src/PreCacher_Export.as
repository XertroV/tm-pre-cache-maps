namespace PreCacher {
    // use this to precache maps or other assets. safe to call more than once with the same URL (prints log 2nd+ time).
    import void PreCacheAsset(const string &in url) from "PreCacher";
    // this retrieves a map url from nadeo and precaches it. safe to call more than once with the same UID (does nothing 2nd+ time). Will yield.
    import void CheckAndCacheMapIfNew_Async(const string &in uid, const string &in name = "<Unk Name>") from "PreCacher";
}

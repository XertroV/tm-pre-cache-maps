# Pre-Cache Maps

Requires: **MLHook** and **MLFeed**. You need to have those plugins installed.

### Reduces map change time on servers to near zero.

Works like this:

- While in a server, check the list of maps on the server.
- If there are any new maps, get the game to download and cache the map.
- When the timer nears 0, also check again (to help with RMT style map changing).
- Then, when the server changes map, you don't need to download the map from the server because you already have it.
- Boom! Instant map changes.

### For Plugin Devs

Exports:

```asc
namespace PreCacher {
    // use this to precache maps or other assets. safe to call more than once with the same URL (prints log 2nd+ time).
    import void PreCacheAsset(const string &in url) from "PreCacher";
    // this retrieves a map url from nadeo and precaches it. safe to call more than once with the same UID (does nothing 2nd+ time). Will yield.
    import void CheckAndCacheMapIfNew_Async(const string &in uid, const string &in name = "<Unk Name>") from "PreCacher";
}
```

Useful if you want this functionality without BetterRoomManager.

License: Public Domain

Authors: XertroV

Suggestions/feedback: @XertroV on Openplanet discord

Code/issues: [https://github.com/XertroV/tm-pre-cache-maps](https://github.com/XertroV/tm-pre-cache-maps)

GL HF

#import <AppKit/AppKit.h>
#import <dlfcn.h>
#import <signal.h>

// The bridge runs under the system Perl host: current macOS does not return
// MediaRemote metadata to an ordinary ad-hoc signed app. No entitlements or
// system settings are changed. Only QQ Music data crosses the local pipe.
static NSString *const QQBundleID = @"com.tencent.QQMusicMac";
static void (*getPID)(dispatch_queue_t, void (^)(int));
static void (*getInfo)(dispatch_queue_t, void (^)(CFDictionaryRef));
static void (*getPlaying)(dispatch_queue_t, void (^)(Boolean));
static Boolean (*sendCommand)(int, CFDictionaryRef);
static NSUInteger generation;
static BOOL fetching;
static NSDate *fetchStarted;
static NSString *lastArtworkKey;
static pid_t parentPID;

static void emit(NSDictionary *object) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:object options:0 error:nil];
    if (!data) return;
    fwrite(data.bytes, 1, data.length, stdout);
    fputc('\n', stdout);
    fflush(stdout);
}

static BOOL isQQ(int pid) {
    return pid > 0 && [[NSRunningApplication runningApplicationWithProcessIdentifier:pid].bundleIdentifier isEqualToString:QQBundleID];
}

static NSString *textValue(NSDictionary *info, NSString *key) {
    id value = info[key];
    return [value isKindOfClass:NSString.class] ? value : @"";
}

static NSNumber *numberValue(NSDictionary *info, NSString *key) {
    id value = info[key];
    double number = [value isKindOfClass:NSNumber.class] ? [value doubleValue] : 0;
    return @(isfinite(number) ? MAX(0, number) : 0);
}

static void poll(void) {
    if (getppid() != parentPID) exit(0);
    if (fetching && -fetchStarted.timeIntervalSinceNow < 4) return;
    fetching = YES;
    fetchStarted = [NSDate date];
    NSUInteger request = ++generation;
    getPID(dispatch_get_main_queue(), ^(int pid) {
        if (request != generation) return;
        if (!isQQ(pid)) {
            fetching = NO;
            lastArtworkKey = nil;
            emit(@{@"kind": @"snapshot", @"bundleID": QQBundleID, @"available": @NO});
            return;
        }
        getInfo(dispatch_get_main_queue(), ^(CFDictionaryRef raw) {
            if (request != generation) return;
            NSDictionary *info = (__bridge NSDictionary *)raw;
            getPlaying(dispatch_get_main_queue(), ^(Boolean playing) {
                // Recheck the owner after fetching to reject mixed snapshots
                // when another player takes over while callbacks are pending.
                getPID(dispatch_get_main_queue(), ^(int currentPID) {
                    if (request != generation) return;
                    fetching = NO;
                    if (currentPID != pid || !isQQ(currentPID)) { poll(); return; }
                    NSString *title = textValue(info, @"kMRMediaRemoteNowPlayingInfoTitle");
                    if (!title.length) {
                        emit(@{@"kind": @"snapshot", @"bundleID": QQBundleID, @"available": @NO});
                        return;
                    }
                    double duration = numberValue(info, @"kMRMediaRemoteNowPlayingInfoDuration").doubleValue;
                    double elapsed = numberValue(info, @"kMRMediaRemoteNowPlayingInfoElapsedTime").doubleValue;
                    NSDate *timestamp = info[@"kMRMediaRemoteNowPlayingInfoTimestamp"];
                    // The separate playing callback is authoritative; QQ can
                    // retain playbackRate = 1 while paused.
                    if (playing && [timestamp isKindOfClass:NSDate.class]) {
                        double delta = -timestamp.timeIntervalSinceNow;
                        if (delta >= 0 && delta < 30) elapsed += delta;
                    }
                    NSString *artist = textValue(info, @"kMRMediaRemoteNowPlayingInfoArtist");
                    NSString *album = textValue(info, @"kMRMediaRemoteNowPlayingInfoAlbum");
                    NSString *trackID = [NSString stringWithFormat:@"%@\x1f%@\x1f%@\x1f%.3f", title, artist, album, duration];
                    NSMutableDictionary *snapshot = [@{
                        @"kind": @"snapshot", @"bundleID": QQBundleID, @"available": @YES,
                        @"playing": @(playing != 0), @"title": title, @"artist": artist,
                        @"album": album, @"trackID": trackID, @"duration": @(duration),
                        @"position": @(MAX(0, MIN(elapsed, duration))), @"pid": @(pid)
                    } mutableCopy];
                    // QQ reports zero or the last resume position when paused,
                    // even though its own window retains the actual position.
                    // Only running snapshots are a reliable position source.
                    snapshot[@"positionAvailable"] = @(playing != 0);
                    NSData *art = info[@"kMRMediaRemoteNowPlayingInfoArtworkData"];
                    NSString *artKey = [trackID stringByAppendingString:textValue(info, @"kMRMediaRemoteNowPlayingInfoArtworkIdentifier")];
                    if ([art isKindOfClass:NSData.class] && art.length > 0 && art.length <= 2 * 1024 * 1024 && ![artKey isEqualToString:lastArtworkKey]) {
                        snapshot[@"artwork"] = [art base64EncodedStringWithOptions:0];
                        lastArtworkKey = artKey;
                    }
                    emit(snapshot);
                });
            });
        });
    });
}

static void command(NSString *line) {
    NSDictionary *commands = @{@"toggle": @2, @"next": @4, @"previous": @5};
    NSNumber *value = commands[line];
    if (!value) return;
    getPID(dispatch_get_main_queue(), ^(int pid) {
        if (!isQQ(pid)) {
            emit(@{@"kind": @"error", @"message": @"请先在 QQ 音乐中开始播放"});
            return;
        }
        if (!sendCommand(value.intValue, NULL)) {
            emit(@{@"kind": @"error", @"message": @"QQ 音乐暂未响应，请在应用中重试"});
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 350 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ poll(); });
    });
}

// XSUB entrypoint: Perl passes its interpreter and CV; neither is inspected.
// This function does not return to Perl, so no Perl ABI structures are needed.
__attribute__((visibility("default"))) void renotch_qq_music_start(void *interpreter, void *cv) {
    @autoreleasepool {
        signal(SIGPIPE, SIG_DFL);
        parentPID = getppid();
        void *library = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY);
        getPID = dlsym(library, "MRMediaRemoteGetNowPlayingApplicationPID");
        getInfo = dlsym(library, "MRMediaRemoteGetNowPlayingInfo");
        getPlaying = dlsym(library, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
        sendCommand = dlsym(library, "MRMediaRemoteSendCommand");
        if (!library || !getPID || !getInfo || !getPlaying || !sendCommand) {
            emit(@{@"kind": @"error", @"message": @"当前系统暂不支持 QQ 音乐联动"});
            exit(1);
        }
        emit(@{@"kind": @"ready"});
        // Input is a tiny allowlist, never shell code or arbitrary app IDs.
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            char buffer[64];
            while (fgets(buffer, sizeof(buffer), stdin)) {
                @autoreleasepool {
                    NSString *line = [[NSString stringWithUTF8String:buffer] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
                    if (line) dispatch_async(dispatch_get_main_queue(), ^{ command(line); });
                }
            }
            exit(0);
        });
        [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer) { poll(); }];
        poll();
        [[NSRunLoop mainRunLoop] run];
        exit(0);
    }
}

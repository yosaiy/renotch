(() => {
if (globalThis.__renotchBrowserActivityInstalled) return;
globalThis.__renotchBrowserActivityInstalled = true;

const sessionID = crypto.randomUUID();
let attachedVideo;
let lastPayload;

function currentVideoID() {
  const url = new URL(location.href);
  if (url.pathname === "/watch") return url.searchParams.get("v");
  const shortsMatch = url.pathname.match(/^\/shorts\/([^/?]+)/);
  return shortsMatch?.[1] || null;
}

function textContent(selectors) {
  for (const selector of selectors) {
    const value = document.querySelector(selector)?.textContent?.trim();
    if (value) return value;
  }
  return "";
}

function mediaPayload(video) {
  const videoID = currentVideoID();
  if (!videoID) return null;

  const title = textContent([
    "h1.ytd-watch-metadata yt-formatted-string",
    "h1.title yt-formatted-string",
    "meta[itemprop='name']"
  ]) || document.title.replace(/\s*-\s*YouTube\s*$/, "") || "YouTube";
  const channel = textContent([
    "ytd-watch-metadata ytd-channel-name a",
    "#owner-name a",
    "ytd-reel-player-header-renderer #channel-name"
  ]) || "YouTube";

  return {
    kind: "media",
    action: "update",
    sessionID,
    title,
    channel,
    url: location.href,
    thumbnailURL: `https://i.ytimg.com/vi/${encodeURIComponent(videoID)}/hqdefault.jpg`,
    isPlaying: !video.paused && !video.ended,
    position: Number.isFinite(video.currentTime) ? video.currentTime : 0,
    duration: Number.isFinite(video.duration) ? video.duration : 0
  };
}

function emit(force = false) {
  const video = document.querySelector("video");
  if (!video || (video.paused && document.hidden)) {
    clearActivity();
    return;
  }

  attach(video);
  const payload = mediaPayload(video);
  if (!payload) {
    clearActivity();
    return;
  }

  const serialized = JSON.stringify(payload);
  if (!force && serialized === lastPayload) return;
  lastPayload = serialized;
  chrome.runtime.sendMessage(payload).catch(() => {});
}

function clearActivity() {
  if (lastPayload === undefined) return;
  lastPayload = undefined;
  chrome.runtime.sendMessage({ kind: "media", action: "clear", sessionID }).catch(() => {});
}

function attach(video) {
  if (attachedVideo === video) return;
  if (attachedVideo) {
    ["play", "pause", "ended", "loadedmetadata", "durationchange"].forEach((event) => {
      attachedVideo.removeEventListener(event, emit);
    });
  }
  attachedVideo = video;
  ["play", "pause", "ended", "loadedmetadata", "durationchange"].forEach((event) => {
    video.addEventListener(event, emit);
  });
}

new MutationObserver(() => emit()).observe(document.documentElement, {
  childList: true,
  subtree: true
});
document.addEventListener("visibilitychange", () => emit(true));
window.addEventListener("pagehide", clearActivity);
setInterval(() => emit(true), 2000);
emit(true);
})();

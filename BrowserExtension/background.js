const HOST_NAME = "com.vincentyosi.renotch.browser_bridge";
const activeMediaSessions = new Map();
let nativePort;
let reconnectTimer;
let downloadPollTimer;

function connectNative() {
  if (nativePort) return nativePort;

  try {
    nativePort = chrome.runtime.connectNative(HOST_NAME);
    nativePort.onDisconnect.addListener(() => {
      void chrome.runtime.lastError;
      nativePort = undefined;
      clearTimeout(reconnectTimer);
      reconnectTimer = setTimeout(connectNative, 1500);
    });
    nativePort.onMessage.addListener(() => {});
  } catch (_error) {
    nativePort = undefined;
    clearTimeout(reconnectTimer);
    reconnectTimer = setTimeout(connectNative, 1500);
  }
  return nativePort;
}

function postToApp(message) {
  try {
    connectNative()?.postMessage({ version: 1, ...message });
  } catch (_error) {
    nativePort = undefined;
    connectNative();
  }
}

chrome.runtime.onMessage.addListener((message, sender) => {
  if (message?.kind !== "media" || !sender.tab) return;
  const sessionID = `${sender.tab.id}:${message.sessionID}`;

  if (message.action === "clear") {
    activeMediaSessions.delete(sessionID);
    postToApp({ kind: "media", action: "clear", sessionID });
    return;
  }

  activeMediaSessions.set(sessionID, Date.now());
  postToApp({ ...message, version: 1, sessionID });
});

chrome.tabs.onRemoved.addListener((tabID) => {
  for (const sessionID of activeMediaSessions.keys()) {
    if (!sessionID.startsWith(`${tabID}:`)) continue;
    activeMediaSessions.delete(sessionID);
    postToApp({ kind: "media", action: "clear", sessionID });
  }
});

function sendDownload(download) {
  postToApp({
    kind: "download",
    action: "update",
    downloadID: download.id,
    filename: download.filename,
    url: download.finalUrl || download.url,
    bytesReceived: download.bytesReceived,
    totalBytes: download.totalBytes,
    state: download.state,
    paused: download.paused
  });
}

async function refreshDownload(downloadID) {
  const results = await chrome.downloads.search({ id: downloadID });
  if (results[0]) sendDownload(results[0]);
}

async function pollActiveDownloads() {
  const downloads = await chrome.downloads.search({ state: "in_progress" });
  downloads.forEach(sendDownload);
  if (downloads.length === 0) stopDownloadPolling();
}

function startDownloadPolling() {
  if (downloadPollTimer) return;
  pollActiveDownloads();
  downloadPollTimer = setInterval(pollActiveDownloads, 500);
}

function stopDownloadPolling() {
  if (!downloadPollTimer) return;
  clearInterval(downloadPollTimer);
  downloadPollTimer = undefined;
}

async function injectExistingYouTubeTabs() {
  try {
    const tabs = await chrome.tabs.query({
      url: ["https://www.youtube.com/*", "https://m.youtube.com/*"]
    });
    await Promise.all(tabs.filter((tab) => tab.id).map((tab) =>
      chrome.scripting.executeScript({
        target: { tabId: tab.id },
        files: ["youtube.js"]
      }).catch(() => {})
    ));
  } catch (_error) {
    // Static content-script injection still handles future navigations.
  }
}

chrome.downloads.onCreated.addListener((download) => {
  sendDownload(download);
  startDownloadPolling();
});

chrome.downloads.onChanged.addListener((delta) => {
  refreshDownload(delta.id);
  if (delta.state?.current === "in_progress") startDownloadPolling();
});

chrome.downloads.onErased.addListener((downloadID) => {
  postToApp({ kind: "download", action: "clear", downloadID });
});

chrome.runtime.onStartup.addListener(() => {
  startDownloadPolling();
  injectExistingYouTubeTabs();
});
chrome.runtime.onInstalled.addListener(() => {
  startDownloadPolling();
  injectExistingYouTubeTabs();
});
connectNative();
startDownloadPolling();
injectExistingYouTubeTabs();

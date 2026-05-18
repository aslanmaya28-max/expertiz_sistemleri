/**
 * YERİMEBAK AI - Background Service Worker
 * Routes messages between popup and content scripts.
 */

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.action === 'EXTRACT_DATA') {
    // Forward to the active tab's content script (handled by popup.js directly)
    sendResponse({ error: 'Use chrome.tabs.sendMessage from popup.' });
  }
  return true;
});

// Extension installed / updated
chrome.runtime.onInstalled.addListener((details) => {
  if (details.reason === 'install') {
    console.log('YERİMEBAK AI Extension installed.');
  }
});
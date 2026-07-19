import QtQuick 2.2
import Sailfish.Silica 1.0
import Sailfish.WebView 1.0
import Sailfish.WebView.Popups 1.0
import Sailfish.WebEngine 1.0

Page {
    id: appSettings

    property string uuid;
    property string url;
    property var pebble;
    allowedOrientations: Orientation.All

    // Fill the whole page and let the flickable own the header, so its contentHeight spans
    // header + full web page — otherwise a config form taller than the screen can't be
    // scrolled all the way to its Save button.
    WebViewFlickable {
        id: webview
        anchors.fill: parent

        header: PageHeader {
            // The generated data: URL from pebble-clay isn't useful and looks like a bug.
            title: url.substring(0, 5) === "data:" ? qsTr("App settings") : ""
            description: url.substring(0, 5) === "data:" ? "" : url
        }

        // Clay closes the config page by navigating to pebblejs://close#<data>. Sailfish's
        // gecko (91) doesn't support the legacy chrome.manifest protocol handler that would
        // have intercepted it, so catch the navigation here instead: parse the action out of
        // the pebble URL and hand the settings back to the watchapp.
        function handlePebbleUrl(u) {
            if (u.indexOf("pebblejs://") !== 0 && u.indexOf("pebble://") !== 0)
                return false;
            console.log("pebble config close url:", u);
            var hIdx = u.indexOf("://") + 3;
            var hashIdx = u.indexOf("#");
            var action = hashIdx >= 0 ? u.substring(hIdx, hashIdx) : u.substring(hIdx);
            if (action.indexOf("close") === 0) {
                // The watchapp's webviewclosed handler (pebble-clay) wants only the fragment
                // after '#' — the URL-encoded config JSON — not the whole pebblejs://close URL.
                var response = hashIdx >= 0 ? u.substring(hashIdx + 1) : "";
                pebble.configurationClosed(appSettings.uuid, response);
                pageStack.pop();
            } else if (action.indexOf("custom-boot-config-url") === 0) {
                var params = unescape(u).split("?");
                for (var i = 0; i < params.length; i++) {
                    if (params[i].substr(0, 13) === "access_token=") {
                        pebble.setOAuthToken(params[i].split("=")[1]);
                        break;
                    }
                }
                pageStack.pop();
            }
            return true;
        }

        webView {
            clip: true
            focus: true
            active: true

            url: appSettings.url
            onUrlChanged: handlePebbleUrl("" + webView.url)
            onViewInitialized: {
                // Belt-and-braces: also accept the handler's async message if it ever works.
                webView.addMessageListener("embed:pebble");
            }
            onRecvAsyncMessage: {
                console.log("Message",message);
                switch(message) {
                case "embed:pebble": {
                    if(data.action === "close") {
                        pebble.configurationClosed(appSettings.uuid, data.uri);
                        pageStack.pop();
                    } else if(data.action === "custom-boot-config-url") {
                        var newUrl = unescape(url);
                        console.log(newUrl);
                        var params = newUrl.split("?");
                        for(var i = 0;i<params.length; i++) {
                            if(params[i].substr(0,13) === "access_token=") {
                                var kv = params[i].split("=");
                                console.log("Found token",kv[1]);
                                pebble.setOAuthToken(kv[1]);
                                break;
                            }
                        }
                        pageStack.pop();
                    }
                    break;
                }
                default:
                    console.log("Data",JSON.stringify(data));
                }
            }
        }
    }
}

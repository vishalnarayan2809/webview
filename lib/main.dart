import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:js/js.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Viewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.grey[900],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[800],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide.none,
          ),
          hintStyle: TextStyle(color: Colors.grey[400]),
        ),
      ),
      home: const HomePage(),
    );
  }
}

@JS('document.exitFullscreen')
external void exitFullscreen();

@JS('document.documentElement.requestFullscreen')
external void requestFullscreen();

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _urlController = TextEditingController();

  String _imageUrl = '';

  bool _isMenuOpen = false;

  bool _isFullscreen = false;

  InAppWebViewController? _webViewController;

  // HTML content for our embedded view.
  String get _htmlContent {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body, html {
      margin: 0;
      padding: 0;
      height: 100%;
      width: 100%;
      background-color: #000;
    }
    #fullscreen-container {
      position: relative;
      display: flex;
      justify-content: center;
      align-items: center;
      width: 100%;
      height: 100%;
      overflow: hidden;
    }
    #image {
      max-width: 100%;
      max-height: 100%;
      border-radius: 12px;
      z-index: 1;
    }
    #corner-exit-button {
      position: absolute;
      bottom: 20px;
      right: 20px;
      padding: 8px 12px;
      border-radius: 5px;
      background-color: grey;
      color: white;
      cursor: pointer;
      z-index: 999999;
      display: none;
      align-items: center;
      gap: 8px;
    }
    #corner-exit-button::before {
      content: '\\26F6'; 
      font-size: 16px;
      color: white;
    }
  </style>
</head>
<body>
  <div id="fullscreen-container">
    <img id="image" src="${_imageUrl.isNotEmpty ? _imageUrl : ''}" />
    <button id="corner-exit-button">Exit Full Screen</button>
  </div>
  <script>
    (function() {
      console.log('Script started');
      const container = document.getElementById('fullscreen-container');
      const cornerExitButton = document.getElementById('corner-exit-button');

      if (!container) {
        console.error('Container not found!');
        return;
      }

    
      container.addEventListener('dblclick', () => {
        console.log('Container double-clicked');
        toggleFullscreen();
      });
      cornerExitButton.addEventListener('click', () => {
        console.log('Exit button clicked');
        if (document.fullscreenElement) {
          document.exitFullscreen().catch(err => {
            console.error('Failed to exit fullscreen:', err);
          });
        }
      });

     
      function toggleFullscreen() {
        if (document.fullscreenElement) {
          document.exitFullscreen().then(() => {
            console.log('Exited fullscreen');
          }).catch(err => {
            console.error('Failed to exit fullscreen:', err);
          });
          cornerExitButton.style.display = 'none';
        } else {
          container.requestFullscreen().then(() => {
            console.log('Entered fullscreen');
            setTimeout(() => {
              cornerExitButton.style.display = 'flex';
            }, 100);
          }).catch(err => {
            console.error('Failed to enter fullscreen:', err);
          });
        }
  }
      document.addEventListener('fullscreenchange', () => {
        if (document.fullscreenElement) {
          setTimeout(() => {
            cornerExitButton.style.display = 'flex';
          }, 100);
        } else {
          cornerExitButton.style.display = 'none';
        }
      });
      
   
      window.addEventListener('message', (event) => {
        console.log('Message received:', event.data);
        if (event.data === 'enterFullscreen' && !document.fullscreenElement) {
          toggleFullscreen();
        } else if (event.data === 'exitFullscreen' && document.fullscreenElement) {
          document.exitFullscreen().catch(err => {
            console.error('Failed to exit fullscreen:', err);
          });
        }
      });
      
      console.log('Script setup complete');
    })();
  </script>
</body>
</html>
''';
  }

  void _enterFullscreen() {
    if (_webViewController != null) {
      _webViewController!.evaluateJavascript(source: '''
        if (!document.fullscreenElement) {
          document.getElementById('fullscreen-container').requestFullscreen().catch(err => {
            console.error('Failed to enter fullscreen:', err);
          });
        }
      ''');
      setState(() {
        _isFullscreen = true;
      });
    }
  }

  void _exitFullscreen() {
    if (_webViewController != null) {
      _webViewController!.evaluateJavascript(source: '''
        if (document.fullscreenElement) {
          document.exitFullscreen().catch(err => {
            console.error('Failed to exit fullscreen:', err);
          });
        }
      ''');
      setState(() {
        _isFullscreen = false;
      });
    }
  }

  void _showContextMenu() {
    setState(() {
      _isMenuOpen = true;
    });
  }

  void _hideContextMenu() {
    setState(() {
      _isMenuOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String viewType = 'iframeElement-${_imageUrl.hashCode}';
    Widget contentWidget;

    if (kIsWeb) {

      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
        final html.IFrameElement element = html.IFrameElement()
          ..srcdoc = _htmlContent
          ..id = 'myIframe'
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allowFullscreen = true;
        return element;
      });
      contentWidget = HtmlElementView(
        key: ValueKey(viewType),
        viewType: viewType,
      );
    } else {
      contentWidget = InAppWebView(
        onWebViewCreated: (controller) {
          _webViewController = controller;
          _webViewController!.addJavaScriptHandler(
            handlerName: 'flutterMessageHandler',
            callback: (args) {
              if (args.isNotEmpty) {
                if (args[0] == 'enterFullscreen') {
                  _enterFullscreen();
                } else if (args[0] == 'exitFullscreen') {
                  _exitFullscreen();
                }
              }
            },
          );
        },
        initialUrlRequest: URLRequest(
          url: WebUri(
            Uri.dataFromString(
              _htmlContent,
              mimeType: 'text/html',
              encoding: Encoding.getByName('utf-8'),
            ).toString(),
          ),
        ),
        initialOptions: InAppWebViewGroupOptions(
          crossPlatform: InAppWebViewOptions(
            javaScriptEnabled: true,
            mediaPlaybackRequiresUserGesture: false,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Viewer', style: TextStyle(color: Colors.grey)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black, Colors.purpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 500,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: contentWidget,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Text field for entering the image URL.
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Enter Image URL',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Button to load the image.
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _imageUrl = _urlController.text.trim();
                        });
                      },
                      child: const Icon(Icons.arrow_forward, size: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),

          // A floating exit button that appears in fullscreen mode.
          if (_isFullscreen)
            Positioned(
              bottom: 20,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.fullscreen_exit, color: Colors.white70),
                onPressed: () {
                  if (kIsWeb) {
                    final element = html.document.getElementById('myIframe');
                    if (element is html.IFrameElement &&
                        element.contentWindow != null) {
                      element.contentWindow!.postMessage('exitFullscreen', '*');
                    }
                  } else {
                    _exitFullscreen();
                  }
                },
              ),
            ),
          if (_isMenuOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _hideContextMenu,
                child: Container(color: Colors.black54),
              ),
            ),
          if (_isMenuOpen)
            Positioned(
              bottom: 70,
              right: 80,
              child: Material(
                color: Colors.grey[850],
                elevation: 10,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    if (kIsWeb) {
                      final element = html.document.getElementById('myIframe');
                      if (element is html.IFrameElement &&
                          element.contentWindow != null) {
                        element.contentWindow!.postMessage('enterFullscreen', '*');
                      }
                    } else {
                      _enterFullscreen();
                    }
                    _hideContextMenu();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 20,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fullscreen, color: Colors.white70),
                        SizedBox(width: 8),
                        Text(
                          'Enter Fullscreen',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        onPressed: _showContextMenu,
        child: const Icon(Icons.more_vert, size: 28),
      ),
    );
  }
}

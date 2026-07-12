import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/constants/app_colors.dart';
import 'payment_api.dart';

/// Outcome the WebView reports back to the caller. Note: `success` here only
/// means "eSewa redirected to the success URL" — it is NOT proof of payment.
/// The caller MUST still call the backend verify endpoint, which re-checks
/// server-to-server before any wallet credit.
enum EsewaResult { success, failure, cancelled }

/// Hosts the eSewa ePay-v2 gateway in an in-app WebView. It auto-POSTs the
/// backend-signed form to eSewa, then intercepts the success/failure redirect
/// and pops with the corresponding [EsewaResult].
class EsewaPaymentWebView extends StatefulWidget {
  final EsewaIntent intent;
  const EsewaPaymentWebView({super.key, required this.intent});

  @override
  State<EsewaPaymentWebView> createState() => _EsewaPaymentWebViewState();
}

class _EsewaPaymentWebViewState extends State<EsewaPaymentWebView> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: _handleNavigation,
        ),
      )
      ..loadHtmlString(_buildAutoSubmitForm());
  }

  /// Intercept the provider redirect. We match on the backend-supplied
  /// success/failure URLs so a page cannot spoof a different outcome.
  NavigationDecision _handleNavigation(NavigationRequest request) {
    final url = request.url;
    if (_matches(url, widget.intent.successUrl)) {
      _finish(EsewaResult.success);
      return NavigationDecision.prevent;
    }
    if (_matches(url, widget.intent.failureUrl)) {
      _finish(EsewaResult.failure);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  bool _matches(String url, String target) {
    if (target.isEmpty) return false;
    final u = Uri.tryParse(url);
    final t = Uri.tryParse(target);
    if (u == null || t == null) return url.startsWith(target);
    // Host + path prefix match; ignores query (eSewa appends ?data=...).
    return u.host == t.host && u.path.startsWith(t.path);
  }

  void _finish(EsewaResult result) {
    if (_popped) return;
    _popped = true;
    Navigator.of(context).pop(result);
  }

  /// A minimal HTML page whose form auto-submits (POST) to eSewa on load.
  String _buildAutoSubmitForm() {
    final inputs = widget.intent.fields.entries
        .map(
          (e) =>
              '<input type="hidden" name="${_esc(e.key)}" value="${_esc(e.value)}">',
        )
        .join('\n');
    return '''
<!DOCTYPE html>
<html>
<head><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body onload="document.forms[0].submit()">
  <form action="${_esc(widget.intent.gatewayUrl)}" method="POST">
    $inputs
  </form>
  <p style="font-family:sans-serif;text-align:center;margin-top:40px;color:#666">
    Redirecting to eSewa…
  </p>
</body>
</html>''';
  }

  // Escape values placed into HTML attributes (defence against breaking out of
  // the attribute even though these come from our own backend).
  String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(EsewaResult.cancelled);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: AppColors.textPrimary),
            onPressed: () => _finish(EsewaResult.cancelled),
          ),
          title: const Text('eSewa Payment'),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading)
              const Center(
                child: CircularProgressIndicator(color: AppColors.driver),
              ),
          ],
        ),
      ),
    );
  }
}

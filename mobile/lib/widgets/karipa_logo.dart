import 'package:flutter/material.dart';

/// Official artwork, including its opaque background and original proportions.
class KaripaLogo extends StatelessWidget {
  const KaripaLogo({
    super.key,
    this.width = 200,
    this.showWordmark = true,
    this.horizontal = false,
    this.blendBackground = false,
  });

  final double width;
  final bool showWordmark;
  final bool horizontal;
  final bool blendBackground;

  Widget _artwork(String path) {
    Widget image = Image.asset(path, fit: BoxFit.contain);
    if (blendBackground) {
      // Fade only the outer 4% background margin. Artwork stays untouched.
      for (final vertical in [false, true]) {
        image = ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
            end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
            colors: const [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent
            ],
            stops: const [0, 0.04, 0.96, 1],
          ).createShader(bounds),
          child: image,
        );
      }
    }
    return image;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Karipa',
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          child: horizontal && showWordmark
              ? Row(children: [
                  Expanded(child: _artwork('assets/branding/karipa-logo.png')),
                  Expanded(
                      flex: 3,
                      child: _artwork('assets/branding/karipa-wordmark.png')),
                ])
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _artwork('assets/branding/karipa-logo.png'),
                    if (showWordmark)
                      _artwork('assets/branding/karipa-wordmark.png'),
                  ],
                ),
        ),
      ),
    );
  }
}

import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
// import 'package:image/image.dart' as img;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:miru_app/utils/i18n.dart';
import 'package:miru_app/utils/request.dart';
import 'package:miru_app/views/widgets/messenger.dart';
import 'package:miru_app/views/widgets/platform_widget.dart';

class CacheNetWorkImagePic extends StatelessWidget {
  const CacheNetWorkImagePic(this.url,
      {super.key,
      this.fit = BoxFit.cover,
      this.width,
      this.height,
      this.fallback,
      this.headers,
      this.placeholder,
      this.canFullScreen = false,
      this.mode = ExtendedImageMode.none,
      this.reconstructKey});
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? fallback;
  final Map<String, String>? headers;
  final bool canFullScreen;
  final Widget? placeholder;
  final ExtendedImageMode mode;
  final List<List<int>>? reconstructKey;
  static final imageCache = <String, Widget>{};
  static void clearCache() {
    imageCache.clear();
  }

  _errorBuild() {
    if (fallback != null) {
      return fallback!;
    }
    return const Center(child: Icon(fluent.FluentIcons.error));
  }

  //save return reconstructed image
  //Future<Image> getPic(url) async {
  //   try {
  //     final res = await dio.get(url,
  //         options: Options(headers: headers, responseType: ResponseType.bytes));
  //     final image = img.decodeImage(res.data);

  //     if (image != null) {
  //       logger.info(image.width, image.height);

  //       // Calculate the size of each slice
  //       int sliceWidth = image.width ~/ 3;
  //       int sliceHeight = image.height ~/ 3;

  //       // Create a 3x3 grid of slices
  //       List<img.Image> imgslices = [];
  //       for (int y = 0; y < 3; y++) {
  //         for (int x = 0; x < 3; x++) {
  //           img.Image slice = img.copyCrop(image,
  //               x: x * sliceWidth,
  //               y: y * sliceHeight,
  //               width: sliceWidth,
  //               height: sliceHeight);
  //           imgslices.add(slice);
  //         }
  //       }
  //       final indexList = [1, 0, 2, 3, 4, 5, 6, 7, 8];
  //       List<img.Image> slices = List<img.Image>.generate(
  //           indexList.length, (i) => imgslices[indexList[i]]);

  //       // Recreate the image from the shuffled slices
  //       img.Image newImage =
  //           img.Image(width: image.width, height: image.height);
  //       for (int y = 0; y < 3; y++) {
  //         for (int x = 0; x < 3; x++) {
  //           img.compositeImage(newImage, slices[y * 3 + x],
  //               dstX: x * sliceWidth, dstY: y * sliceHeight);
  //         }
  //       }

  //       // Convert the new image to a byte array
  //       Uint8List newImageData = img.encodePng(newImage);

  //       // Return the new image as an ExtendedImage
  //       return Image.memory(newImageData);
  //     }
  //     return _errorBuild();
  //   } catch (e) {
  //     return _errorBuild();
  //   }
  // }

  Future<ImageInfo> _getImageSize(String url) async {
    final Completer<ImageInfo> completer = Completer();
    final ImageStream stream =
        ExtendedNetworkImageProvider(cache: true, url, headers: headers)
            .resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener((ImageInfo info, bool _) {
      if (!completer.isCompleted) {
        completer.complete(info);
      }
    });

    stream.addListener(listener);
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    if (reconstructKey != null) {
      //image cache for reconstruct image
      if (imageCache.containsKey(url)) {
        return imageCache[url]!;
      }
      return FutureBuilder(
          future: _getImageSize(url),
          builder: (contex, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.hasData) {
                final image = snapshot.data!.image;
                final double width = image.width.toDouble();
                final double height = image.height.toDouble();
                final widthSegment = width / reconstructKey![0].length;
                final heightSegment = height / reconstructKey!.length;
                final reconstructImage = List<Widget>.filled(
                    reconstructKey!.length * reconstructKey![0].length,
                    Container());
                final expandedList =
                    reconstructKey!.expand((element) => element).toList();
                // logger.info(expandedList);
                for (int i = 0; i < expandedList.length; i++) {
                  final x = i % reconstructKey![0].length;
                  final y = i ~/ reconstructKey![0].length;
                  // logger.info([i, x, y]);
                  final targetIndex = expandedList.indexOf(i);
                  final targetX = targetIndex % reconstructKey![0].length;
                  final targetY = targetIndex ~/ reconstructKey![0].length;

                  reconstructImage[i] = Transform.translate(
                    offset: Offset((targetX - x) * widthSegment,
                        (targetY - y) * heightSegment),
                    child: (RepaintBoundary(
                        child: ClipRect(
                      clipBehavior: Clip.hardEdge,
                      clipper: ImageClipper(
                          pointa: Offset(x * widthSegment, y * heightSegment),
                          pointb: Offset(
                              (x + 1) * widthSegment, (y + 1) * heightSegment)),
                      child: RawImage(image: image),
                    ))),
                  );
                }
                final img = FittedBox(
                  fit: fit,
                  child: Stack(
                    children: reconstructImage,
                  ),
                );
                imageCache[url] = img;
                return img;
              }
            }
            return placeholder ?? const SizedBox();
          });
    }
    final image = ExtendedImage.network(
      url,
      headers: headers,
      fit: fit,
      width: width,
      height: height,
      cache: true,
      mode: mode,
      loadStateChanged: (state) {
        switch (state.extendedImageLoadState) {
          case LoadState.loading:
            return placeholder ?? const SizedBox();
          case LoadState.completed:
            return state.completedWidget;
          case LoadState.failed:
            return _errorBuild();
        }
      },
    );

    if (canFullScreen) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            final thumnailPage = _ThumnailPage(
              url: url,
              headers: headers,
            );
            if (Platform.isAndroid) {
              Get.to(thumnailPage);
              return;
            }
            fluent.showDialog(
              context: context,
              builder: (_) => thumnailPage,
            );
          },
          child: image,
        ),
      );
    }

    return image;
  }
}

class _ThumnailPage extends StatefulWidget {
  const _ThumnailPage({
    required this.url,
    required this.headers,
  });
  final String url;
  final Map<String, String>? headers;

  @override
  State<_ThumnailPage> createState() => _ThumnailPageState();
}

class _ThumnailPageState extends State<_ThumnailPage> {
  final menuController = fluent.FlyoutController();
  final contextAttachKey = GlobalKey();

  @override
  dispose() {
    menuController.dispose();
    super.dispose();
  }

  _saveImage() async {
    final url = widget.url;
    final fileName = url.split('/').last;
    final res = await dio.get(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: widget.headers,
      ),
    );
    if (Platform.isAndroid) {
      final result = await ImageGallerySaver.saveImage(
        res.data,
        name: fileName,
      );
      if (mounted) {
        final msg = result['isSuccess'] == true
            ? 'common.save-success'.i18n
            : result['errorMessage'];
        showPlatformSnackbar(
          context: context,
          content: msg,
        );
      }
      return;
    }
    // 打开目录选择对话框file_picker

    final path = await FilePicker.platform.saveFile(
      type: FileType.image,
      fileName: fileName,
    );
    if (path == null) {
      return;
    }
    // 保存
    File(path).writeAsBytesSync(res.data);
  }

  Widget _buildContent(BuildContext context) {
    return Center(
      child: ExtendedImageSlidePage(
        slideAxis: SlideAxis.both,
        slideType: SlideType.onlyImage,
        slidePageBackgroundHandler: (offset, pageSize) {
          final color = Platform.isAndroid
              ? Theme.of(context).scaffoldBackgroundColor
              : fluent.FluentTheme.of(context).scaffoldBackgroundColor;
          return color.withOpacity(0);
        },
        child: ExtendedImage.network(
          widget.url,
          headers: widget.headers,
          cache: true,
          fit: BoxFit.contain,
          mode: ExtendedImageMode.gesture,
          initGestureConfigHandler: (state) {
            return GestureConfig(
              minScale: 0.9,
              animationMinScale: 0.7,
              maxScale: 3.0,
              animationMaxScale: 3.5,
              speed: 1.0,
              inertialSpeed: 100.0,
              initialScale: 1.0,
              inPageView: true,
              reverseMousePointerScrollDirection: true,
              initialAlignment: InitialAlignment.center,
            );
          },
        ),
      ),
    );
  }

  Widget _buildAndroid(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: GestureDetector(
        child: _buildContent(context),
        onLongPress: () {
          showModalBottomSheet(
            context: context,
            showDragHandle: true,
            useSafeArea: true,
            builder: (_) => SizedBox(
              height: 100,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.save),
                    title: Text('common.save'.i18n),
                    onTap: () {
                      Navigator.of(context).pop();
                      _saveImage();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    return GestureDetector(
      onSecondaryTapUp: (d) {
        final targetContext = contextAttachKey.currentContext;
        if (targetContext == null) return;
        final box = targetContext.findRenderObject() as RenderBox;
        final position = box.localToGlobal(
          d.localPosition,
          ancestor: Navigator.of(context).context.findRenderObject(),
        );
        menuController.showFlyout(
          position: position,
          builder: (context) {
            return fluent.MenuFlyout(items: [
              fluent.MenuFlyoutItem(
                leading: const Icon(fluent.FluentIcons.save),
                text: Text('common.save'.i18n),
                onPressed: () {
                  fluent.Flyout.of(context).close();
                  _saveImage();
                },
              ),
            ]);
          },
        );
      },
      child: fluent.FlyoutTarget(
        key: contextAttachKey,
        controller: menuController,
        child: _buildContent(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PlatformBuildWidget(
      androidBuilder: _buildAndroid,
      desktopBuilder: _buildDesktop,
    );
  }
}

class ImageClipper extends CustomClipper<Rect> {
  const ImageClipper({Key? key, required this.pointa, required this.pointb});
  final Offset pointa;
  final Offset pointb;
  @override
  Rect getClip(Size size) => Rect.fromPoints(pointa, pointb);

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) => false;
}

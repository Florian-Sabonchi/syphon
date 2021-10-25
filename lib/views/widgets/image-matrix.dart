import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:syphon/global/dimensions.dart';
import 'package:syphon/global/print.dart';
import 'package:syphon/store/index.dart';
import 'package:syphon/store/media/actions.dart';
import 'package:syphon/store/media/model.dart';
import 'package:syphon/views/widgets/lifecycle.dart';

///
/// Matrix Image
///
/// uses the matrix mxc uris and either pulls from cached data
/// or downloads the image and saves it to cache
///
/// TODO: optimize widget rebuilds, the ViewModel equatable updates
/// too frequently as is but none of the data is changing
///
class MatrixImage extends StatefulWidget {
  final String? mxcUri;
  final double width;
  final double height;
  final double? size;
  final double strokeWidth;
  final double loadingPadding;
  final String? imageType;
  final BoxFit fit;
  final bool thumbnail;
  final bool rebuild;
  final bool forceLoading;
  final Widget? fallback;
  final Color fallbackColor;

  const MatrixImage({
    Key? key,
    required this.mxcUri,
    this.width = Dimensions.avatarSizeMin,
    this.height = Dimensions.avatarSizeMin,
    this.size,
    this.strokeWidth = Dimensions.strokeWidthThin,
    this.imageType,
    this.loadingPadding = 0,
    this.fit = BoxFit.fill,
    this.thumbnail = true,
    this.rebuild = true,
    this.forceLoading = false,
    this.fallbackColor = Colors.grey,
    this.fallback,
  }) : super(key: key);

  @override
  MatrixImageState createState() => MatrixImageState();
}

class MatrixImageState extends State<MatrixImage> with Lifecycle<MatrixImage> {
  Uint8List? finalUriData;

  @override
  void onMounted({bool rebuild = true}) {
    final store = StoreProvider.of<AppState>(context);
    final mediaCache = store.state.mediaStore.mediaCache;

    if (!mediaCache.containsKey(widget.mxcUri)) {
      store.dispatch(fetchMedia(mxcUri: widget.mxcUri, thumbnail: widget.thumbnail));
    }

    // Attempts to reduce framerate drop in chat details
    // not sure this actually works as it still drops on scroll
    if (rebuild && mediaCache.containsKey(widget.mxcUri)) {
      printInfo('[onMounted] disabled rebuild');
      finalUriData = mediaCache[widget.mxcUri!];
    }
  }

  // TODO: potentially revert to didChangeDependencies
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    onMounted(rebuild: true);
  }

  @override
  Widget build(BuildContext context) => StoreConnector<AppState, _Props>(
        distinct: true,
        converter: (Store<AppState> store) => _Props.mapStateToProps(store, widget.mxcUri),
        builder: (context, props) {
          final failed = props.mediaStatus != null && props.mediaStatus == MediaStatus.FAILURE.value;
          final loading = widget.forceLoading || !props.exists;

          if (failed) {
            return CircleAvatar(
              radius: 24,
              backgroundColor: widget.fallbackColor,
              child: widget.fallback ??
                  Icon(
                    Icons.photo,
                    color: Colors.white,
                  ),
            );
          }

          if (loading) {
            return Container(
                width: widget.size ?? widget.width,
                height: widget.size ?? widget.height,
                child: Padding(
                  padding: EdgeInsets.all(widget.loadingPadding),
                  child: CircularProgressIndicator(
                    strokeWidth: widget.strokeWidth * 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.secondary,
                    ),
                    value: null,
                  ),
                ));
          }

          return Image(
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            image: MemoryImage(
              props.mediaCache ?? finalUriData!,
            ),
          );
        },
      );
}

class _Props extends Equatable {
  final bool exists;
  final String? mediaStatus;
  final Uint8List? mediaCache;

  const _Props({
    required this.exists,
    required this.mediaStatus,
    required this.mediaCache,
  });

  @override
  List<Object?> get props => [
        exists,
        mediaStatus,
        mediaCache,
      ];

  static _Props mapStateToProps(Store<AppState> store, String? mxcUri) => _Props(
        exists: store.state.mediaStore.mediaCache[mxcUri] != null,
        mediaCache: store.state.mediaStore.mediaCache[mxcUri],
        mediaStatus: store.state.mediaStore.mediaStatus[mxcUri],
      );
}

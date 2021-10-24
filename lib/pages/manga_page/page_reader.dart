import 'dart:async';
import 'package:extensions/extensions.dart' as extensions;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import './update_tracker.dart';
import '../../components/toggleable_appbar.dart';
import '../../components/toggleable_slide_widget.dart';
import '../../plugins/database/schemas/settings/settings.dart'
    show MangaDirections, MangaSwipeDirections, MangaMode;
import '../../plugins/helpers/screen.dart';
import '../../plugins/helpers/stateful_holder.dart';
import '../../plugins/helpers/ui.dart';
import '../../plugins/state.dart' show AppState;
import '../../plugins/translator/translator.dart';
import '../settings_page/setting_labels/manga.dart';

enum TapSpace {
  left,
  middle,
  right,
}

TapSpace _spaceFromPosition(final double position) {
  if (position <= 0.3) return TapSpace.left;
  if (position >= 0.7) return TapSpace.right;
  return TapSpace.middle;
}

class LastTapDetail {
  LastTapDetail(this.space, this.time);

  final TapSpace space;
  final DateTime time;
}

class PageReader extends StatefulWidget {
  const PageReader({
    required final this.extractor,
    required final this.info,
    required final this.chapter,
    required final this.pages,
    required final this.onPop,
    required final this.previousChapter,
    required final this.nextChapter,
    final Key? key,
  }) : super(key: key);

  final extensions.MangaExtractor extractor;
  final extensions.MangaInfo info;
  final extensions.ChapterInfo chapter;
  final List<extensions.PageInfo> pages;

  final void Function() onPop;
  final void Function() previousChapter;
  final void Function() nextChapter;

  @override
  _PageReaderState createState() => _PageReaderState();
}

class _PageReaderState extends State<PageReader>
    with SingleTickerProviderStateMixin, FullscreenMixin {
  final Duration animationDuration = const Duration(milliseconds: 300);

  late AnimationController overlayController;
  bool showOverlay = true;

  final ValueNotifier<Widget?> footerNotificationContent =
      ValueNotifier<Widget?>(null);
  Timer? footerNotificationTimer;
  final Duration footerNotificationDuration = const Duration(seconds: 3);

  late TransformationController interactiveController;
  bool interactionOnProgress = false;
  LastTapDetail? lastTapDetail;

  late PageController pageController;
  late int currentPage;
  late int currentIndex;

  bool isHorizontal = AppState.settings.current.mangaReaderSwipeDirection ==
      MangaSwipeDirections.horizontal;
  bool isReversed = AppState.settings.current.mangaReaderDirection ==
      MangaDirections.rightToLeft;

  late final Map<extensions.PageInfo, StatefulHolder<extensions.ImageInfo?>>
      images = <extensions.PageInfo, StatefulHolder<extensions.ImageInfo?>>{};

  final Widget loader = const Center(
    child: CircularProgressIndicator(),
  );

  bool hasSynced = false;
  bool ignoreExitFullscreen = false;

  @override
  void initState() {
    super.initState();

    initFullscreen();
    if (AppState.settings.current.mangaAutoFullscreen) {
      enterFullscreen();
    }

    overlayController = AnimationController(
      vsync: this,
      duration: animationDuration,
    );

    interactiveController = TransformationController();

    currentPage = 0;
    currentIndex =
        isReversed ? widget.pages.length - currentPage - 1 : currentPage;
    pageController = PageController(
      initialPage: currentIndex,
    );
  }

  @override
  void dispose() {
    if (!ignoreExitFullscreen) {
      exitFullscreen();
    }

    footerNotificationTimer?.cancel();
    footerNotificationContent.dispose();

    overlayController.dispose();
    interactiveController.dispose();
    pageController.dispose();

    super.dispose();
  }

  Future<void> goToPage(final int page) async {
    await pageController.animateToPage(
      isReversed ? widget.pages.length - page - 1 : page,
      duration: animationDuration,
      curve: Curves.easeInOut,
    );

    if (page == widget.pages.length - 1) {
      hasSynced = true;

      await updateTrackers(
        widget.info.title,
        widget.extractor.id,
        widget.chapter.chapter,
        widget.chapter.volume,
      );
    }
  }

  Future<void> getPage(final extensions.PageInfo page) async {
    images[page]!.state = LoadState.resolving;
    final extensions.ImageInfo image = await widget.extractor.getPage(page);
    setState(() {
      images[page]!.value = image;
      images[page]!.state = LoadState.resolved;
    });
  }

  void showOptions() {
    showModalBottomSheet(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(remToPx(0.5)),
          topRight: Radius.circular(remToPx(0.5)),
        ),
      ),
      context: context,
      builder: (final BuildContext context) => SafeArea(
        child: StatefulBuilder(
          builder: (
            final BuildContext context,
            final StateSetter setState,
          ) =>
              Padding(
            padding: EdgeInsets.symmetric(vertical: remToPx(0.25)),
            child: Wrap(
              children: <Widget>[
                Column(
                  children: getManga(AppState.settings.current, () async {
                    await AppState.settings.current.save();

                    if (AppState.settings.current.mangaReaderMode !=
                        MangaMode.page) {
                      AppState.settings.modify(AppState.settings.current);
                    }

                    setState(() {
                      isReversed =
                          AppState.settings.current.mangaReaderDirection ==
                              MangaDirections.rightToLeft;
                      isHorizontal =
                          AppState.settings.current.mangaReaderSwipeDirection ==
                              MangaSwipeDirections.horizontal;
                    });
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _prevPage(final bool satisfied) {
    if (currentPage > 0) {
      goToPage(currentPage - 1);
      return true;
    } else {
      if (satisfied) {
        ignoreExitFullscreen = true;
        widget.previousChapter();
        return true;
      }
    }
    return false;
  }

  bool _nextPage(final bool satisfied) {
    if (currentPage + 1 < widget.pages.length) {
      goToPage(currentPage + 1);
      return true;
    } else {
      if (satisfied) {
        ignoreExitFullscreen = true;
        widget.nextChapter();
        return true;
      }
    }
    return false;
  }

  void showFooterNotification(final Widget? child) {
    footerNotificationContent.value = child;
    footerNotificationTimer?.cancel();

    if (footerNotificationContent.value != null) {
      footerNotificationTimer = Timer(footerNotificationDuration, () {
        showFooterNotification(null);
      });
    }
  }

  @override
  Widget build(final BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: ToggleableAppBar(
          controller: overlayController,
          visible: showOverlay,
          child: AppBar(
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: Translator.t.back(),
              onPressed: widget.onPop,
            ),
            actions: <Widget>[
              ValueListenableBuilder<bool>(
                valueListenable: isFullscreened,
                builder: (
                  final BuildContext builder,
                  final bool isFullscreened,
                  final Widget? child,
                ) =>
                    IconButton(
                  onPressed: () async {
                    AppState.settings.current.mangaAutoFullscreen =
                        !isFullscreened;

                    if (isFullscreened) {
                      exitFullscreen();
                    } else {
                      enterFullscreen();
                    }

                    await AppState.settings.current.save();
                  },
                  icon: Icon(
                    isFullscreened ? Icons.fullscreen_exit : Icons.fullscreen,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  showOptions();
                },
                icon: const Icon(Icons.more_vert),
              ),
            ],
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.info.title,
                ),
                Text(
                  '${widget.chapter.volume != null ? '${Translator.t.vol()} ${widget.chapter.volume} ' : ''}${Translator.t.ch()} ${widget.chapter.chapter} ${widget.chapter.title != null ? '- ${widget.chapter.title}' : ''}',
                  style: TextStyle(
                    fontSize: Theme.of(context).textTheme.subtitle2?.fontSize,
                  ),
                ),
              ],
            ),
          ),
        ),
        body: widget.pages.isEmpty
            ? Center(
                child: Text(
                  Translator.t.noPagesFound(),
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                ),
              )
            : GestureDetector(
                onTapUp: (final TapUpDetails details) async {
                  final LastTapDetail currentTap = LastTapDetail(
                    _spaceFromPosition(
                      details.localPosition.dx /
                          MediaQuery.of(context).size.width,
                    ),
                    DateTime.now(),
                  );

                  final bool useDoubleClick =
                      AppState.settings.current.doubleClickSwitchChapter;
                  final bool satisfied = !useDoubleClick ||
                      lastTapDetail?.space == currentTap.space &&
                          (currentTap.time.millisecondsSinceEpoch -
                                  lastTapDetail!.time.millisecondsSinceEpoch) <=
                              kDoubleTapTimeout.inMilliseconds;

                  bool done = false;
                  if (currentTap.space == TapSpace.left) {
                    done = isReversed
                        ? _nextPage(satisfied)
                        : _prevPage(satisfied);
                  } else if (currentTap.space == TapSpace.right) {
                    done = isReversed
                        ? _prevPage(satisfied)
                        : _nextPage(satisfied);
                  } else {
                    setState(() {
                      showOverlay = !showOverlay;
                    });
                    done = true;
                  }

                  lastTapDetail = currentTap;

                  if (!done && currentTap.space != TapSpace.middle) {
                    final bool isPrev = isReversed
                        ? currentTap.space == TapSpace.right
                        : currentTap.space == TapSpace.left;
                    showFooterNotification(
                      Text(
                        isPrev
                            ? Translator.t.tapAgainToSwitchPreviousChapter()
                            : Translator.t.tapAgainToSwitchNextChapter(),
                        key: UniqueKey(),
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    );
                  }
                },
                child: PageView.builder(
                  allowImplicitScrolling: true,
                  scrollDirection:
                      AppState.settings.current.mangaReaderSwipeDirection ==
                              MangaSwipeDirections.horizontal
                          ? Axis.horizontal
                          : Axis.vertical,
                  onPageChanged: (final int page) {
                    setState(() {
                      currentPage =
                          isReversed ? widget.pages.length - page - 1 : page;
                      currentIndex = page;
                    });

                    interactiveController.value = Matrix4.identity();
                  },
                  physics: interactionOnProgress
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  controller: pageController,
                  itemCount: widget.pages.length,
                  itemBuilder: (final BuildContext context, final int _index) {
                    final int index =
                        isReversed ? widget.pages.length - _index - 1 : _index;
                    final extensions.PageInfo page = widget.pages[index];

                    if (images[page] == null) {
                      images[page] =
                          StatefulHolder<extensions.ImageInfo?>(null);
                    }

                    if (!images[page]!.hasValue) {
                      if (!images[page]!.isResolving) {
                        getPage(page);
                      }

                      return loader;
                    }

                    final extensions.ImageInfo image = images[page]!.value!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(
                          child: Image.network(
                            image.url,
                            headers: image.headers,
                            loadingBuilder: (
                              final BuildContext context,
                              final Widget child,
                              final ImageChunkEvent? loadingProgress,
                            ) {
                              if (loadingProgress == null) {
                                return InteractiveViewer(
                                  transformationController:
                                      interactiveController,
                                  child: child,
                                  onInteractionEnd:
                                      (final ScaleEndDetails details) {
                                    setState(() {
                                      interactionOnProgress =
                                          interactiveController.value
                                                  .getMaxScaleOnAxis() !=
                                              1;
                                    });
                                  },
                                );
                              }

                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(
                          height: remToPx(0.5),
                        ),
                        ValueListenableBuilder<Widget?>(
                          valueListenable: footerNotificationContent,
                          builder: (
                            final BuildContext context,
                            final Widget? footerNotificationContent,
                            final Widget? child,
                          ) =>
                              Align(
                            child: AnimatedSwitcher(
                              duration: animationDuration,
                              child: footerNotificationContent ?? child!,
                            ),
                          ),
                          child: Text(
                            '${index + 1}/${widget.pages.length}',
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: remToPx(0.3),
                        ),
                      ],
                    );
                  },
                ),
              ),
        bottomNavigationBar: ToggleableSlideWidget(
          offsetBegin: Offset.zero,
          offsetEnd: const Offset(0, 1),
          visible: showOverlay,
          controller: overlayController,
          curve: Curves.easeInOut,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: remToPx(0.5),
              vertical:
                  remToPx(1) + Theme.of(context).textTheme.subtitle2!.fontSize!,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(
                  Radius.circular(remToPx(0.25)),
                ),
                color: Theme.of(context).cardColor,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: remToPx(0.5),
                ),
                child: Row(
                  children: <Widget>[
                    Material(
                      type: MaterialType.transparency,
                      shape: const CircleBorder(),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(
                          Theme.of(context).textTheme.headline4!.fontSize!,
                        ),
                        onTap: () {
                          ignoreExitFullscreen = true;
                          widget.previousChapter();
                        },
                        child: Icon(
                          Icons.first_page,
                          size: Theme.of(context).textTheme.headline4?.fontSize,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Wrap(
                        children: <Widget>[
                          SliderTheme(
                            data: SliderThemeData(
                              thumbShape: RoundSliderThumbShape(
                                enabledThumbRadius: remToPx(0.3),
                              ),
                              trackHeight: remToPx(0.15),
                              showValueIndicator: ShowValueIndicator.always,
                            ),
                            child: Slider(
                              value: currentPage + 1,
                              min: 1,
                              max: widget.pages.length.toDouble(),
                              label: (currentPage + 1).toString(),
                              onChanged: (final double value) {
                                setState(() {
                                  currentPage = value.toInt() - 1;
                                });
                              },
                              onChangeEnd: (final double value) async {
                                goToPage(value.toInt() - 1);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      type: MaterialType.transparency,
                      shape: const CircleBorder(),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(
                          Theme.of(context).textTheme.headline4!.fontSize!,
                        ),
                        onTap: () {
                          ignoreExitFullscreen = true;
                          widget.nextChapter();
                        },
                        child: Icon(
                          Icons.last_page,
                          size: Theme.of(context).textTheme.headline4?.fontSize,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

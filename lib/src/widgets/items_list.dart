import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tatlacas_flutter_core/tatlacas_flutter_core.dart';

class ItemsList<TBloc extends ItemsManagerBloc> extends StatefulWidget {
  final ItemsListState<TBloc> Function()? stateBuilder;

  const ItemsList({
    Key? key,
    this.stateBuilder,
    this.buildSliversInSliverOverlapInjector = false,
    this.useFixedCrossAxisCount = false,
    this.fixedCrossAxisCount = 1,
    this.maxCrossAxisExtent = 200,
    this.childAspectRatio = 1,
    this.crossAxisSpacing = 16,
    this.mainAxisSpacing = 16,
  }) : super(key: key);

  final bool buildSliversInSliverOverlapInjector;

  final bool useFixedCrossAxisCount;

  final int fixedCrossAxisCount;

  final double maxCrossAxisExtent;

  final double childAspectRatio;

  final double crossAxisSpacing;

  final double mainAxisSpacing;

  @override
  ItemsListState<TBloc> createState() =>
      stateBuilder?.call() ?? ItemsListState<TBloc>();
}

class ItemsListState<TBloc extends ItemsManagerBloc>
    extends State<ItemsList<TBloc>>
    with AutomaticKeepAliveClientMixin {
  late TBloc bloc;

  bool get hasRefreshIndicator => true;

  bool get floatHeaderSlivers => false;

  bool get useNestedScrollView => true;

  final ScrollController scrollController = ScrollController();

  bool get buildSliversInSliverOverlapInjector => false;

  final Map<int, GlobalKey<SliverAnimatedListState>> _animatedListKeys =
  Map<int, GlobalKey<SliverAnimatedListState>>();

  @protected
  SliverAnimatedListState _animatedList(int section) {
    if (_animatedListKeys[section] == null)
      resetAnimatedListKey(section);
    return _animatedListKeys[section]!.currentState!;
  }

  @protected
  void resetAnimatedListKey(dynamic section) {
    assert(section is int);
    if (!useAnimatedList(section)) return;
    _animatedListKeys[section] = new GlobalKey<SliverAnimatedListState>();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    bloc = context.read<TBloc>();
    return useNestedScrollView
        ? NestedScrollView(
        controller: scrollController,
        floatHeaderSlivers: floatHeaderSlivers,
        headerSliverBuilder:
            (BuildContext context, bool innerBoxIsScrolled) {
          return buildAppBarSlivers(context);
        },
        body: buildScrollView(context))
        : buildScrollView(context);
  }

  Widget buildScrollView(BuildContext context) {
    return hasRefreshIndicator
        ? RefreshIndicator(
      onRefresh: () async {
        bloc.add(ReloadItemsRequested(context: context));
      },
      child: buildCustomScrollView(context),
    )
        : buildCustomScrollView(context);
  }

  Widget buildCustomScrollView(BuildContext context) {
    return BlocConsumer<TBloc, ItemsManagerState>(
      listener: (context, state) {
        if (state is ItemRemoved) {
          removeListItem(state.removedItem,
              section: state.itemSection, index: state.itemIndex);
        } else if (state is ItemInserted) {
          insertListItem(state.insertedItem,
              section: state.itemSection,
              index: state.itemIndex,
              isReplace: false);
        }
      },
      listenWhen: (prev, next) => next is ItemChanged,
      buildWhen: (prev, next) => next is ItemsBuildUi,
      builder: (context, state) {
        return buildOnStateChanged(context, state);
      },
    );
  }

  Widget buildOnStateChanged(BuildContext context,
      ItemsManagerState state,) {
    if (state is ItemsLoading) return buildLoadingView(context);
    if (state is LoadItemsFailed) return _buildLoadingFailed(context);
    if (state is LoadItemsFailed) return _buildLoadingFailed(context);
    if (state is ItemsLoaded || state is ItemReplaced)
      return _buildCustomScrollView(context);
    throw ArgumentError('buildOnStateChanged Not supported state $state');
  }

  Widget _buildCustomScrollView(BuildContext context) {
    var withInjector = widget.buildSliversInSliverOverlapInjector ||
        buildSliversInSliverOverlapInjector;
    return CustomScrollView(
      key: PageStorageKey<String>(TBloc.runtimeType.toString()),
      physics:
      const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      //needed for RefreshIndicator to work
      slivers: withInjector
          ? buildSectionsWithOverlapInjector(context)
          : buildSections(context),
    );
  }

  Widget _buildLoadingFailed(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        var bloc = context.read<TBloc>();
        bloc.add(ReloadItemsRequested(context: context));
      },
      child: CustomScrollView(
        key: PageStorageKey<String>(TBloc.runtimeType.toString()),
        slivers: buildLoadingFailedSlivers(context),
      ),
    );
  }

  List<Widget> buildLoadingFailedSlivers(BuildContext context) {
    return [
      SliverPadding(
        padding: EdgeInsets.only(left: 20, right: 20, bottom: 20),
        sliver: SliverFillRemaining(
          hasScrollBody: false,
          child: buildLoadingFailedWidget(context),
        ),
      )
    ];
  }

  Widget buildLoadingFailedWidget(BuildContext context) {
    return Center(
      child: Text('Show Screen Failed to load items widget here...'),
    );
  }

  Widget buildLoadingView(BuildContext context) {
    return Center(
      child: SizedBox(
        child: CircularProgressIndicator(),
        width: 60,
        height: 60,
      ),
    );
  }

  bool useAnimatedList(int section) => true;

  List<Widget> buildSectionsWithOverlapInjector(BuildContext context) {
    var sections = buildSections(context);
    List<Widget> widgets = [
      SliverOverlapInjector(
// This is the flip side of the SliverOverlapAbsorber
// above.
        handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
      ),
    ];
    widgets.addAll(sections);
    return widgets;
  }

  List<Widget> buildAppBarSlivers(BuildContext context) {
    return [];
  }

  List<Widget> buildSections(BuildContext context) {
    final state = bloc.state as LoadedItemsState;
    final List<Widget> sections = []; //buildAppBarSlivers(context);
    if (state.isNotEmpty) {
      for (int sectionIndex = 0;
      sectionIndex < state.totalSections;
      sectionIndex++) {
        if (state.sectionHeader(sectionIndex) != null) {
          sections.add(buildSectionHeaderSliver(
              sectionIndex, context, state.sectionHeader(sectionIndex)));
        }
        double marginBottom = sectionIndex == state.totalSections - 1 ? 80 : 0;
        if (state
            .section(sectionIndex)
            .isEmpty) {
          sections.add(buildEmptySectionSliver(context));
        } else {
          sections.add(
            state.usesGrid(sectionIndex)
                ? sectionSliverGrid(sectionIndex, context,
                state.section(sectionIndex), marginBottom)
                : sectionSliverList(sectionIndex, context,
                state.section(sectionIndex), marginBottom),
          );
        }
      }
    } else {
      sections.add(buildEmptySliver(context));
    }
    return sections;
  }

  Widget buildEmptySectionSliver(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: 20),
      sliver: SliverToBoxAdapter(
        child: buildEmptyView(context, emptyMessage: 'Empty Section View'),
      ),
    );
  }

  Widget buildEmptySliver(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: 20),
      sliver: SliverFillRemaining(
        hasScrollBody: false,
        child: buildEmptyView(context),
      ),
    );
  }

  Widget buildSectionHeaderSliver(int section, BuildContext context,
      dynamic sectionHeader) {
    return SliverToBoxAdapter(
      child: buildSectionHeader(section, context, sectionHeader),
    );
  }

  Widget buildSectionHeader(int section, BuildContext context,
      dynamic sectionHeader) {
    if (sectionHeader is Widgetable) {
      return sectionHeader.build(
          onClick: () =>
              onListHeaderClick(
                context: context,
                section: section,
                item: sectionHeader,
              ));
    }
    throw ArgumentError("unsupported list header item $sectionHeader");
  }

  Widget sectionSliverGrid(int sectionIndex, BuildContext context,
      Section section, double marginBottom) {
    return section.horizontalScroll
        ? buildHorizontalSliverGrid(sectionIndex, section)
        : buildVerticalSliverGrid(sectionIndex, section);
  }

  Widget sectionSliverList(int section, BuildContext context,
      Section sectionItems, double marginBottom) {
    return sectionItems.horizontalScroll
        ? buildHorizontalSliverList(section, sectionItems)
        : buildVerticalSliverList(section, sectionItems);
  }

  Widget buildHorizontalSliverGrid(int section, Section sectionItems) {
    return SliverToBoxAdapter(
      child: Container(
        height: sectionItems.horizontalScrollHeight,
        child: GridView.builder(
          gridDelegate: _buildSliverGridDelegate(),
          itemBuilder: (context, index) {
            return buildListItem(
              context: context,
              section: section,
              index: index,
              item: sectionItems.items[index],
            );
          },
          itemCount: sectionItems.totalItems(),
          scrollDirection: Axis.horizontal,
        ),
      ),
    );
  }

  Widget buildVerticalSliverGrid(int section, Section sectionItems) {
    return useAnimatedList(section)
        ? buildVerticalSliverGridAnimated(section, sectionItems)
        : buildVerticalSliverGridDefault(section, sectionItems);
  }

  Widget buildHorizontalSliverList(int section, Section sectionItems) {
    return SliverToBoxAdapter(
      child: Container(
        height: sectionItems.horizontalScrollHeight,
        child: useAnimatedList(section)
            ? _buildHorizontalAnimatedList(section, sectionItems)
            : _buildHorizontalList(section, sectionItems),
      ),
    );
  }

  Widget buildVerticalSliverList(int section, Section sectionItems) {
    return useAnimatedList(section)
        ? _buildVerticalSliverAnimatedList(section, sectionItems)
        : buildVerticalSliverListDefault(section, sectionItems);
  }

  SliverGrid buildVerticalSliverGridDefault(int section, Section sectionItems) {
    return SliverGrid(
      key: Key("${section}sectionSliverGrid"),
      gridDelegate: _buildSliverGridDelegate(),
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          return buildListItem(
            context: context,
            section: section,
            index: index,
            item: sectionItems.items[index],
          );
        },
        childCount: sectionItems.totalItems(),
      ),
    );
  }

  Widget buildVerticalSliverGridAnimated(int section, Section sectionItems) {
    return SliverGrid(
      key: Key("${section}sectionSliverGrid"),
      gridDelegate: _buildSliverGridDelegate(),
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          return buildListItem(
            context: context,
            section: section,
            index: index,
            item: sectionItems.items[index],
          );
        },
        childCount: sectionItems.totalItems(),
      ),
    );
    ;
  }

  Widget buildListItem({
    required BuildContext context,
    required int section,
    required int index,
    required dynamic item,
    Animation<double>? animation,
    bool isReplace = false,
    bool isRemoved = false,
  }) {
    if (item is Widgetable) {
      return item.build(
          animation: animation,
          onClick: () =>
              onListItemClick(
                context: context,
                item: item,
                section: section,
                index: index,
              ));
    }
    throw ArgumentError('unsupported list item $item');
  }

  FutureOr<void> onListItemClick({
    required BuildContext context,
    required dynamic item,
    required int section,
    required int index,
  }) {
    print('List item clicked. Remember to handle this..');
  }

  FutureOr<void> onListHeaderClick({
    required BuildContext context,
    required int section,
    required dynamic item,
  }) {
    print('Header item clicked. Remember to handle this..');
  }

  SliverGridDelegate _buildSliverGridDelegate() {
    return widget.useFixedCrossAxisCount
        ? SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: widget.fixedCrossAxisCount,
      childAspectRatio: widget.childAspectRatio,
      crossAxisSpacing: widget.crossAxisSpacing,
      mainAxisSpacing: widget.mainAxisSpacing,
    )
        : SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: widget.maxCrossAxisExtent,
      childAspectRatio: widget.childAspectRatio,
      crossAxisSpacing: widget.crossAxisSpacing,
      mainAxisSpacing: widget.mainAxisSpacing,
    );
  }

  ListView _buildHorizontalList(int section, Section sectionItems) {
    return ListView.builder(
      itemBuilder: (context, index) {
        return buildListItem(
          context: context,
          section: section,
          index: index,
          item: sectionItems.items[index],
        );
      },
      itemCount: sectionItems.totalItems(),
      scrollDirection: Axis.horizontal,
    );
  }

  Widget _buildHorizontalAnimatedList(int section, Section sectionItems) {
    if (!_animatedListKeys.containsKey(section)) {
      _animatedListKeys[section] = GlobalKey<SliverAnimatedListState>();
    }
    return AnimatedList(
      key: _animatedListKeys[section],
      itemBuilder:
          (BuildContext context, int index, Animation<double> animation) =>
          buildAnimatedListItem(
              context: context,
              index: index,
              animation: animation,
              section: section,
              item: sectionItems.items[index]),
      initialItemCount: sectionItems.totalItems(),
      scrollDirection: Axis.horizontal,
    );
  }

  Widget buildVerticalSliverListDefault(int section, Section sectionItems) {
    return SliverList(
      key: ValueKey('${section}sectionSliverList'),
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          return buildListItem(
            context: context,
            section: section,
            index: index,
            item: sectionItems.items[index],
          );
        },
        childCount: sectionItems.totalItems(),
      ),
    );
  }

  Widget _buildVerticalSliverAnimatedList(int section, Section sectionItems) {
    if (!_animatedListKeys.containsKey(section)) {
      _animatedListKeys[section] = GlobalKey<SliverAnimatedListState>();
    }
    return SliverAnimatedList(
      key: _animatedListKeys[section],
      itemBuilder:
          (BuildContext context, int index, Animation<double> animation) =>
          buildAnimatedListItem(
              context: context,
              index: index,
              animation: animation,
              section: section,
              item: sectionItems.items[index]),
      initialItemCount: sectionItems.totalItems(),
    );
  }

  @protected
  Widget buildAnimatedListItem({
    required BuildContext context,
    required int index,
    required Animation<double> animation,
    required int section,
    required dynamic item,
  }) {
    final isReplace =
    bloc.isReplacingItem(section: section, index: index, item: item);
    if (isReplace)
      return buildAnimatedReplaceListItem(
          context: context,
          index: index,
          animation: animation,
          section: section,
          item: item);
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0,
        end: 1,
      ).animate(animation),
      child: buildListItem(
        context: context,
        section: section,
        index: index,
        animation: animation,
        item: item,
      ),
    );
  }

  @protected
  Widget buildAnimatedReplaceListItem({
    required BuildContext context,
    required int index,
    required Animation<double> animation,
    required int section,
    required dynamic item,
  }) {
    return buildListItem(
        context: context,
        section: section,
        index: index,
        animation: animation,
        item: item,
        isReplace: true);
  }

  @protected
  Widget buildRemovedListItem({required dynamic item,
    required int index,
    required int section,
    required BuildContext context,
    required Animation<double> animation,
    required bool isReplace}) {
    if (isReplace)
      return buildListItem(
        context: context,
        section: section,
        index: index,
        animation: animation,
        item: item,
        isRemoved: true,
      );
    return buildAnimatedListItem(
        context: context,
        index: index,
        animation: animation,
        section: section,
        item: item);
  }

  void removeListItem(dynamic removedItem, {
    required int section,
    required int index,
    Duration duration = const Duration(milliseconds: 300),
    bool isReplace = false,
  }) {
    _animatedList(section).removeItem(
      index,
          (context, animation) =>
          buildRemovedListItem(
              item: removedItem,
              index: index,
              section: section,
              context: context,
              animation: animation,
              isReplace: isReplace),
      duration: duration,
    );
  }

  void insertListItem(dynamic insertedItem, {
    required int section,
    required int index,
    required bool isReplace,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    _animatedList(section).insertItem(index, duration: duration);
  }

  Widget buildEmptyView(BuildContext context, {String? emptyMessage}) {
    return Center(child: Text(emptyMessage ?? 'Empty View'));
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;
}
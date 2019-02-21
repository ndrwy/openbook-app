import 'dart:async';

import 'package:Openbook/provider.dart';
import 'package:Openbook/services/httpie.dart';
import 'package:Openbook/services/toast.dart';
import 'package:Openbook/widgets/icon.dart';
import 'package:Openbook/widgets/progress_indicator.dart';
import 'package:Openbook/widgets/search_bar.dart';
import 'package:Openbook/widgets/theming/text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:loadmore/loadmore.dart';

class OBHttpList<T> extends StatefulWidget {
  final OBHttpListSearcherItemBuilder<T> itemBuilder;
  final OBHttpListSearcher<T> listSearcher;
  final OBHttpListBootstrapper<T> listBootstrapper;
  final OBHttpListMoreLoader<T> listMoreLoader;
  final OBHttpListController controller;
  final String searchBarPlaceholder;

  const OBHttpList(
      {Key key,
      @required this.itemBuilder,
      @required this.listSearcher,
      @required this.listBootstrapper,
      @required this.listMoreLoader,
      this.searchBarPlaceholder = 'Search..',
      this.controller})
      : super(key: key);

  @override
  OBHttpListState createState() {
    return OBHttpListState<T>();
  }
}

class OBHttpListState<T> extends State<OBHttpList> {
  ToastService _toastService;

  GlobalKey<RefreshIndicatorState> _listRefreshIndicatorKey;
  ScrollController _listScrollController;
  List<T> _list = [];
  List<T> _listSearchResults = [];

  bool _hasSearch;
  String _searchQuery;
  bool _needsBootstrap;
  bool _refreshInProgress;
  bool _searchRequestInProgress;
  bool _loadingFinished;

  StreamSubscription<List<T>> _searchRequestSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) widget.controller.attach(this);
    _listScrollController = ScrollController();
    _listRefreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
    _loadingFinished = false;
    _needsBootstrap = true;
    _refreshInProgress = false;
    _searchRequestInProgress = false;
    _hasSearch = false;
    _list = [];
    _searchQuery = '';
  }

  void insertListItem(T listItem) {
    this._list.insert(0, listItem);
    this._setList(this._list.toList());
    scrollToTop();
  }

  void removeListItem(T listItem) {
    setState(() {
      _list.remove(listItem);
      _listSearchResults.remove(listItem);
    });
  }

  void scrollToTop() {
    _listScrollController.animateTo(
      0.0,
      curve: Curves.easeOut,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_needsBootstrap) {
      var provider = OpenbookProvider.of(context);
      _toastService = provider.toastService;
      _bootstrap();
      _needsBootstrap = false;
    }

    return Column(
      children: <Widget>[
        SizedBox(
            child: OBSearchBar(
          onSearch: _onSearch,
          hintText: widget.searchBarPlaceholder,
        )),
        Expanded(child: _hasSearch ? _buildSearchResultsList() : _buildList()),
      ],
    );
  }

  Widget _buildSearchResultsList() {
    return NotificationListener(
      onNotification: (ScrollNotification notification) {
        // Hide keyboard
        return true;
      },
      child: ListView.builder(
          padding: EdgeInsets.all(0),
          physics: const ClampingScrollPhysics(),
          itemCount: _listSearchResults.length + 1,
          itemBuilder: _buildSearchResultsListItem),
    );
  }

  Widget _buildSearchResultsListItem(BuildContext context, int index) {
    if (index == _listSearchResults.length) {
      String searchQuery = _searchQuery;

      if (_searchRequestInProgress) {
        // Search in progress
        return ListTile(
            leading: const OBProgressIndicator(),
            title: OBText('Searching for $searchQuery'));
      } else if (_listSearchResults.isEmpty) {
        // Results were empty
        return ListTile(
            leading: const OBIcon(OBIcons.sad),
            title: OBText('No results for $searchQuery.'));
      } else {
        return const SizedBox();
      }
    }

    T listItem = _listSearchResults[index];

    return widget.itemBuilder(context, listItem);
  }

  Widget _buildList() {
    return RefreshIndicator(
        key: _listRefreshIndicatorKey,
        child: LoadMore(
            whenEmptyLoad: false,
            isFinish: _loadingFinished,
            delegate: const OBHttpListLoadMoreDelegate(),
            child: ListView.builder(
                controller: _listScrollController,
                physics: const ClampingScrollPhysics(),
                cacheExtent: 30,
                addAutomaticKeepAlives: true,
                padding: const EdgeInsets.all(0),
                itemCount: _list.length,
                itemBuilder: _buildListItem),
            onLoadMore: _loadMoreListItems),
        onRefresh: _refreshList);
  }

  Widget _buildListItem(BuildContext context, int index) {
    T listItem = _list[index];

    return widget.itemBuilder(context, listItem);
  }

  void _bootstrap() async {
    await _refreshList();
  }

  Future<void> _refreshList() async {
    _setRefreshInProgress(true);
    try {
      _list = await widget.listBootstrapper();
      _setList(_list);
      scrollToTop();
    } catch (error) {
      _onRequestError(error);
    } finally {
      _setRefreshInProgress(false);
    }
  }

  Future<bool> _loadMoreListItems() async {
    try {
      List<T> moreListItems = await widget.listMoreLoader(_list);

      if (moreListItems.length == 0) {
        _setLoadingFinished(true);
      } else {
        _addListItems(moreListItems);
      }
      return true;
    } catch (error) {
      _onRequestError(error);
    }

    return false;
  }

  void _onSearch(String query) {
    _setSearchQuery(query);
    if (query.isEmpty) {
      _setHasSearch(false);
    } else {
      _setHasSearch(true);
      _searchWithQuery(query);
    }
  }

  void _searchWithQuery(String query) {
    if (_searchRequestSubscription != null) _searchRequestSubscription.cancel();

    _setSearchRequestInProgress(true);

    _searchRequestSubscription =
        widget.listSearcher(_searchQuery).asStream().listen(
            (List listSearchResults) {
              _searchRequestSubscription = null;
              _setListSearchResults(listSearchResults);
            },
            onError: _onRequestError,
            onDone: () {
              _setSearchRequestInProgress(false);
            });
  }

  void _resetListSearchResults() {
    _setListSearchResults(_list.toList());
  }

  void _setListSearchResults(List<T> listSearchResults) {
    setState(() {
      _listSearchResults = listSearchResults;
    });
  }

  void _setLoadingFinished(bool loadingFinished) {
    setState(() {
      _loadingFinished = loadingFinished;
    });
  }

  void _setList(List<T> list) {
    setState(() {
      this._list = list;
      _resetListSearchResults();
    });
  }

  void _addListItems(List<T> items) {
    setState(() {
      this._list.addAll(items);
    });
  }

  void _setSearchQuery(String searchQuery) {
    setState(() {
      _searchQuery = searchQuery;
    });
  }

  void _setHasSearch(bool hasSearch) {
    setState(() {
      _hasSearch = hasSearch;
    });
  }

  void _setRefreshInProgress(bool refreshInProgress) {
    setState(() {
      _refreshInProgress = refreshInProgress;
    });
  }

  void _setSearchRequestInProgress(bool searchRequestInProgress) {
    setState(() {
      _searchRequestInProgress = searchRequestInProgress;
    });
  }

  void _onRequestError(error) {
    if (error is HttpieConnectionRefusedError) {
      _toastService.error(message: 'No internet connection', context: context);
    } else {
      _toastService.error(message: 'Unknown error.', context: context);
      throw error;
    }
  }
}

class OBHttpListController<T> {
  OBHttpListState _state;

  void attach(OBHttpListState state) {
    _state = state;
  }

  void insertListItem(T listItem) {
    if (!_isAttached()) return;
    _state.insertListItem(listItem);
  }

  void removeListItem(T listItem) {
    if (!_isAttached()) return;
    _state.removeListItem(listItem);
  }

  void scrollToTop() {
    if (!_isAttached()) return;
    _state.scrollToTop();
  }

  bool _isAttached() {
    return _state != null;
  }
}

typedef Widget OBHttpListSearcherItemBuilder<T>(
    BuildContext context, T listItem);
typedef Future<List<T>> OBHttpListSearcher<T>(String searchQuery);
typedef Future<List<T>> OBHttpListBootstrapper<T>();
typedef Future<List<T>> OBHttpListMoreLoader<T>(List<T> currentList);

class OBHttpListLoadMoreDelegate extends LoadMoreDelegate {
  const OBHttpListLoadMoreDelegate();

  @override
  Widget buildChild(LoadMoreStatus status,
      {LoadMoreTextBuilder builder = DefaultLoadMoreTextBuilder.english}) {
    if (status == LoadMoreStatus.fail) {
      return SizedBox(
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            OBIcon(OBIcons.refresh),
            const SizedBox(
              width: 10.0,
            ),
            OBText('Tap to retry.')
          ],
        ),
      );
    }
    if (status == LoadMoreStatus.loading) {
      return SizedBox(
          child: Center(
        child: OBProgressIndicator(),
      ));
    }
    return const SizedBox();
  }
}

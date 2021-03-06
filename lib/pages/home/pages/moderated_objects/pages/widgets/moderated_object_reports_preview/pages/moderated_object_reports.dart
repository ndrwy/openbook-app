import 'package:Openbook/models/moderation/moderated_object.dart';
import 'package:Openbook/models/moderation/moderation_report.dart';
import 'package:Openbook/models/moderation/moderation_report_list.dart';
import 'package:Openbook/provider.dart';
import 'package:Openbook/services/toast.dart';
import 'package:Openbook/services/user.dart';
import 'package:Openbook/widgets/progress_indicator.dart';
import 'package:async/async.dart';
import 'package:flutter/material.dart';

import '../moderation_report_tile.dart';

class OBModeratedObjectReportsPage extends StatefulWidget {
  final ModeratedObject moderatedObject;

  const OBModeratedObjectReportsPage({Key key, @required this.moderatedObject})
      : super(key: key);

  @override
  OBModeratedObjectReportsPageState createState() {
    return OBModeratedObjectReportsPageState();
  }
}

class OBModeratedObjectReportsPageState
    extends State<OBModeratedObjectReportsPage> {
  bool _needsBootstrap;
  UserService _userService;
  ToastService _toastService;

  CancelableOperation _refreshReportsOperation;
  bool _refreshInProgress;
  List<ModerationReport> _reports;

  @override
  void initState() {
    super.initState();
    _needsBootstrap = true;
    _refreshInProgress = false;
    _reports = [];
  }

  @override
  void dispose() {
    super.dispose();
    if (_refreshReportsOperation != null) _refreshReportsOperation.cancel();
  }

  @override
  Widget build(BuildContext context) {
    if (_needsBootstrap) {
      OpenbookProviderState openbookProvider = OpenbookProvider.of(context);
      _userService = openbookProvider.userService;
      _toastService = openbookProvider.toastService;
      _refreshReports();
      _needsBootstrap = false;
      _refreshInProgress = true;
    }
    return _refreshInProgress
        ? Row(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(20),
                child: OBProgressIndicator(),
              )
            ],
          )
        : ListView.builder(
            itemBuilder: _buildModerationReport,
            itemCount: _reports.length,
          );
  }

  Widget _buildModerationReport(BuildContext contenxt, int index) {
    ModerationReport report = _reports[index];
    return OBModerationReportTile(
      report: report,
    );
  }

  Future _refreshReports() async {
    _setRefreshInProgress(true);
    try {
      _refreshReportsOperation = CancelableOperation.fromFuture(_userService
          .getModeratedObjectReports(widget.moderatedObject, count: 5));

      ModerationReportsList moderationReportsList =
          await _refreshReportsOperation.value;
      _setReports(moderationReportsList.moderationReports);
    } catch (error) {
      _onError(error);
    }
    _setRefreshInProgress(false);
  }

  void _setRefreshInProgress(bool refreshInProgress) {
    setState(() {
      _refreshInProgress = refreshInProgress;
    });
  }

  void _setReports(List<ModerationReport> reports) {
    setState(() {
      _reports = reports;
    });
  }

  void _onError(error) async {
    if (error is HttpieConnectionRefusedError) {
      _toastService.error(
          message: error.toHumanReadableMessage(), context: context);
    } else if (error is HttpieRequestError) {
      String errorMessage = await error.toHumanReadableMessage();
      _toastService.error(message: errorMessage, context: context);
    } else {
      _toastService.error(message: 'Unknown error', context: context);
      throw error;
    }
  }
}

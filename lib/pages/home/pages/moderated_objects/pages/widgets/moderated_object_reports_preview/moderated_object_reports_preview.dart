import 'package:Openbook/models/moderation/moderated_object.dart';
import 'package:Openbook/models/moderation/moderation_report.dart';
import 'package:Openbook/models/moderation/moderation_report_list.dart';
import 'package:Openbook/provider.dart';
import 'package:Openbook/services/navigation_service.dart';
import 'package:Openbook/services/toast.dart';
import 'package:Openbook/services/user.dart';
import 'package:Openbook/widgets/avatars/avatar.dart';
import 'package:Openbook/widgets/buttons/see_all_button.dart';
import 'package:Openbook/widgets/progress_indicator.dart';
import 'package:Openbook/widgets/theming/divider.dart';
import 'package:Openbook/widgets/theming/secondary_text.dart';
import 'package:Openbook/widgets/theming/text.dart';
import 'package:Openbook/widgets/tile_group_title.dart';
import 'package:Openbook/widgets/tiles/user_tile.dart';
import 'package:async/async.dart';
import 'package:flutter/material.dart';

import 'moderation_report_tile.dart';

class OBModeratedObjectReportsPreview extends StatefulWidget {
  final bool isEditable;
  final ModeratedObject moderatedObject;

  const OBModeratedObjectReportsPreview(
      {Key key, @required this.moderatedObject, @required this.isEditable})
      : super(key: key);

  @override
  OBModeratedObjectReportsPreviewState createState() {
    return OBModeratedObjectReportsPreviewState();
  }
}

class OBModeratedObjectReportsPreviewState
    extends State<OBModeratedObjectReportsPreview> {
  static int reportsPreviewsCount = 5;

  bool _needsBootstrap;
  UserService _userService;
  ToastService _toastService;
  NavigationService _navigationService;

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
      _navigationService = openbookProvider.navigationService;
      _refreshReports();
      _needsBootstrap = false;
      _refreshInProgress = true;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        OBTileGroupTitle(
          title: 'Reports',
        ),
        OBDivider(),
        _refreshInProgress
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: OBProgressIndicator(),
                  )
                ],
              )
            : ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                separatorBuilder: (BuildContext context, int index) {
                  return OBDivider();
                },
                itemBuilder: _buildModerationReport,
                itemCount: _reports.length,
                shrinkWrap: true,
              ),
        OBDivider(),
        OBSeeAllButton(
          previewedResourcesCount: _reports.length,
          resourcesCount: widget.moderatedObject.reportsCount,
          resourceName: 'reports',
          onPressed: _onWantsToSeeAllReports,
        )
      ],
    );
  }

  Widget _buildModerationReport(BuildContext contenxt, int index) {
    ModerationReport report = _reports[index];

    return OBModerationReportTile(report: report);
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

  void _onWantsToSeeAllReports() {
    _navigationService.navigateToModeratedObjectReports(
        context: context, moderatedObject: widget.moderatedObject);
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

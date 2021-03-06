import 'package:Openbook/models/community.dart';
import 'package:Openbook/provider.dart';
import 'package:Openbook/services/navigation_service.dart';
import 'package:Openbook/widgets/icon.dart';
import 'package:Openbook/widgets/theming/text.dart';
import 'package:Openbook/widgets/tiles/loading_tile.dart';
import 'package:flutter/material.dart';

class OBReportCommunityTile extends StatefulWidget {
  final Community community;
  final ValueChanged<dynamic> onCommunityReported;
  final VoidCallback onWantsToReportCommunity;

  const OBReportCommunityTile({
    Key key,
    this.onCommunityReported,
    @required this.community,
    this.onWantsToReportCommunity,
  }) : super(key: key);

  @override
  OBReportCommunityTileState createState() {
    return OBReportCommunityTileState();
  }
}

class OBReportCommunityTileState extends State<OBReportCommunityTile> {
  NavigationService _navigationService;
  bool _requestInProgress;

  @override
  void initState() {
    super.initState();
    _requestInProgress = false;
  }

  @override
  Widget build(BuildContext context) {
    var openbookProvider = OpenbookProvider.of(context);
    _navigationService = openbookProvider.navigationService;

    return StreamBuilder(
      stream: widget.community.updateSubject,
      initialData: widget.community,
      builder: (BuildContext context, AsyncSnapshot<Community> snapshot) {
        var community = snapshot.data;

        bool isReported = community.isReported ?? false;

        return OBLoadingTile(
          isLoading: _requestInProgress || isReported,
          leading: OBIcon(OBIcons.report),
          title: OBText(isReported
              ? 'You have reported this community'
              : 'Report community'),
          onTap: isReported ? () {} : _reportCommunity,
        );
      },
    );
  }

  void _reportCommunity() {
    if (widget.onWantsToReportCommunity != null)
      widget.onWantsToReportCommunity();
    _navigationService.navigateToReportObject(
        context: context,
        object: widget.community,
        onObjectReported: widget.onCommunityReported);
  }
}

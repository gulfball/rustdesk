import 'dart:async';
import 'dart:convert';

import 'package:contextmenu/contextmenu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/desktop/pages/desktop_home_page.dart';
import 'package:flutter_hbb/desktop/widgets/peer_widget.dart';
import 'package:flutter_hbb/utils/multi_window_manager.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../common.dart';
import '../../mobile/pages/home_page.dart';
import '../../mobile/pages/scan_page.dart';
import '../../mobile/pages/settings_page.dart';
import '../../models/model.dart';
import '../../models/peer_model.dart';

enum RemoteType { recently, favorite, discovered, addressBook }

/// Connection page for connecting to a remote peer.
class ConnectionPage extends StatefulWidget implements PageShape {
  ConnectionPage({Key? key}) : super(key: key);

  @override
  final icon = Icon(Icons.connected_tv);

  @override
  final title = translate("Connection");

  @override
  final appBarActions = !isAndroid ? <Widget>[WebMenu()] : <Widget>[];

  @override
  _ConnectionPageState createState() => _ConnectionPageState();
}

/// State for the connection page.
class _ConnectionPageState extends State<ConnectionPage> {
  /// Controller for the id input bar.
  final _idController = TextEditingController();

  /// Update url. If it's not null, means an update is available.
  var _updateUrl = '';
  var _menuPos;

  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _updateTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      updateStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_idController.text.isEmpty) _idController.text = gFFI.getId();
    return Container(
      decoration: BoxDecoration(color: MyTheme.grayBg),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            getUpdateUI(),
            Row(
              children: [
                getSearchBarUI(),
              ],
            ).marginOnly(top: 16.0, left: 16.0),
            SizedBox(height: 12),
            Divider(
              thickness: 1,
            ),
            Expanded(
              child: DefaultTabController(
                  length: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TabBar(
                          labelColor: Colors.black87,
                          isScrollable: true,
                          indicatorSize: TabBarIndicatorSize.label,
                          tabs: [
                            Tab(
                              child: Text(translate("Recent Sessions")),
                            ),
                            Tab(
                              child: Text(translate("Favorites")),
                            ),
                            Tab(
                              child: Text(translate("Discovered")),
                            ),
                            Tab(
                              child: Text(translate("Address Book")),
                            ),
                          ]),
                      Expanded(
                          child: TabBarView(children: [
                        RecentPeerWidget(),
                        FavoritePeerWidget(),
                        DiscoveredPeerWidget(),
                        AddressBookPeerWidget(),
                        // FutureBuilder<Widget>(
                        //     future: getPeers(rType: RemoteType.recently),
                        //     builder: (context, snapshot) {
                        //       if (snapshot.hasData) {
                        //         return snapshot.data!;
                        //       } else {
                        //         return Offstage();
                        //       }
                        //     }),
                        // FutureBuilder<Widget>(
                        //     future: getPeers(rType: RemoteType.favorite),
                        //     builder: (context, snapshot) {
                        //       if (snapshot.hasData) {
                        //         return snapshot.data!;
                        //       } else {
                        //         return Offstage();
                        //       }
                        //     }),
                        // FutureBuilder<Widget>(
                        //     future: getPeers(rType: RemoteType.discovered),
                        //     builder: (context, snapshot) {
                        //       if (snapshot.hasData) {
                        //         return snapshot.data!;
                        //       } else {
                        //         return Offstage();
                        //       }
                        //     }),
                        // FutureBuilder<Widget>(
                        //     future: buildAddressBook(context),
                        //     builder: (context, snapshot) {
                        //       if (snapshot.hasData) {
                        //         return snapshot.data!;
                        //       } else {
                        //         return Offstage();
                        //       }
                        //     }),
                      ]).paddingSymmetric(horizontal: 12.0, vertical: 4.0))
                    ],
                  )),
            ),
            Divider(),
            SizedBox(height: 50, child: Obx(() => buildStatus()))
                .paddingSymmetric(horizontal: 12.0)
          ]),
    );
  }

  /// Callback for the connect button.
  /// Connects to the selected peer.
  void onConnect({bool isFileTransfer = false}) {
    var id = _idController.text.trim();
    connect(id, isFileTransfer: isFileTransfer);
  }

  /// Connect to a peer with [id].
  /// If [isFileTransfer], starts a session only for file transfer.
  void connect(String id, {bool isFileTransfer = false}) async {
    if (id == '') return;
    id = id.replaceAll(' ', '');
    if (isFileTransfer) {
      await rustDeskWinManager.new_file_transfer(id);
    } else {
      await rustDeskWinManager.new_remote_desktop(id);
    }
    FocusScopeNode currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus) {
      currentFocus.unfocus();
    }
  }

  /// UI for software update.
  /// If [_updateUrl] is not empty, shows a button to update the software.
  Widget getUpdateUI() {
    return _updateUrl.isEmpty
        ? SizedBox(height: 0)
        : InkWell(
            onTap: () async {
              final url = _updateUrl + '.apk';
              if (await canLaunch(url)) {
                await launch(url);
              }
            },
            child: Container(
                alignment: AlignmentDirectional.center,
                width: double.infinity,
                color: Colors.pinkAccent,
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(translate('Download new version'),
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold))));
  }

  /// UI for the search bar.
  /// Search for a peer and connect to it if the id exists.
  Widget getSearchBarUI() {
    var w = Container(
      width: 500,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: MyTheme.white,
        borderRadius: const BorderRadius.all(Radius.circular(13)),
      ),
      child: Ink(
        child: Column(
          children: [
            Row(
              children: <Widget>[
                Expanded(
                  child: Container(
                    child: TextField(
                      autocorrect: false,
                      enableSuggestions: false,
                      keyboardType: TextInputType.visiblePassword,
                      // keyboardType: TextInputType.number,
                      style: TextStyle(
                        fontFamily: 'WorkSans',
                        fontWeight: FontWeight.bold,
                        fontSize: 30,
                        // color: MyTheme.idColor,
                      ),
                      decoration: InputDecoration(
                        labelText: translate('Control Remote Desktop'),
                        // hintText: 'Enter your remote ID',
                        // border: InputBorder.,
                        border:
                            OutlineInputBorder(borderRadius: BorderRadius.zero),
                        helperStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: MyTheme.dark,
                        ),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 26,
                          letterSpacing: 0.2,
                          color: MyTheme.dark,
                        ),
                      ),
                      controller: _idController,
                      onSubmitted: (s) {
                        onConnect();
                      },
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      onConnect(isFileTransfer: true);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 8.0),
                      child: Text(
                        translate(
                          "Transfer File",
                        ),
                        style: TextStyle(color: MyTheme.dark),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 30,
                  ),
                  OutlinedButton(
                    onPressed: onConnect,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 16.0),
                      child: Text(
                        translate(
                          "Connection",
                        ),
                        style: TextStyle(color: MyTheme.white),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
    return Center(
        child: Container(constraints: BoxConstraints(maxWidth: 600), child: w));
  }

  @override
  void dispose() {
    _idController.dispose();
    _updateTimer?.cancel();
    super.dispose();
  }

  /// Get the image for the current [platform].
  Widget getPlatformImage(String platform) {
    platform = platform.toLowerCase();
    if (platform == 'mac os')
      platform = 'mac';
    else if (platform != 'linux' && platform != 'android') platform = 'win';
    return Image.asset('assets/$platform.png', height: 50);
  }

  bool hitTag(List<dynamic> selectedTags, List<dynamic> idents) {
    if (selectedTags.isEmpty) {
      return true;
    }
    if (idents.isEmpty) {
      return false;
    }
    for (final tag in selectedTags) {
      if (!idents.contains(tag)) {
        return false;
      }
    }
    return true;
  }

  /// Get all the saved peers.
  Future<Widget> getPeers({RemoteType rType = RemoteType.recently}) async {
    final space = 8.0;
    final cards = <Widget>[];
    List<Peer> peers;
    switch (rType) {
      case RemoteType.recently:
        peers = gFFI.peers();
        break;
      case RemoteType.favorite:
        peers = await gFFI.bind.mainGetFav().then((peers) async {
          final peersEntities = await Future.wait(peers
                  .map((id) => gFFI.bind.mainGetPeers(id: id))
                  .toList(growable: false))
              .then((peers_str) {
            final len = peers_str.length;
            final ps = List<Peer>.empty(growable: true);
            for (var i = 0; i < len; i++) {
              print("${peers[i]}: ${peers_str[i]}");
              ps.add(Peer.fromJson(peers[i], jsonDecode(peers_str[i])['info']));
            }
            return ps;
          });
          return peersEntities;
        });
        break;
      case RemoteType.discovered:
        peers = await gFFI.bind.mainGetLanPeers().then((peers_string) {
          print(peers_string);
          return [];
        });
        break;
      case RemoteType.addressBook:
        peers = gFFI.abModel.peers.map((e) {
          return Peer.fromJson(e['id'], e);
        }).toList();
        break;
    }
    peers.forEach((p) {
      var deco = Rx<BoxDecoration?>(BoxDecoration(
          border: Border.all(color: Colors.transparent, width: 1.0),
          borderRadius: BorderRadius.circular(20)));
      cards.add(Obx(
        () => Offstage(
          offstage: !hitTag(gFFI.abModel.selectedTags, p.tags) &&
              rType == RemoteType.addressBook,
          child: Container(
              width: 225,
              height: 150,
              child: Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  child: MouseRegion(
                    onEnter: (evt) {
                      deco.value = BoxDecoration(
                          border: Border.all(color: Colors.blue, width: 1.0),
                          borderRadius: BorderRadius.circular(20));
                    },
                    onExit: (evt) {
                      deco.value = BoxDecoration(
                          border:
                              Border.all(color: Colors.transparent, width: 1.0),
                          borderRadius: BorderRadius.circular(20));
                    },
                    child: Obx(
                      () => Container(
                        decoration: deco.value,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color:
                                      str2color('${p.id}${p.platform}', 0x7f),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    topRight: Radius.circular(20),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            child: getPlatformImage(
                                                '${p.platform}'),
                                          ),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Tooltip(
                                                  message:
                                                      '${p.username}@${p.hostname}',
                                                  child: Text(
                                                    '${p.username}@${p.hostname}',
                                                    style: TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 12),
                                                    textAlign: TextAlign.center,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ).paddingAll(4.0),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("${p.id}"),
                                InkWell(
                                    child: Icon(Icons.more_vert),
                                    onTapDown: (e) {
                                      final x = e.globalPosition.dx;
                                      final y = e.globalPosition.dy;
                                      _menuPos =
                                          RelativeRect.fromLTRB(x, y, x, y);
                                    },
                                    onTap: () {
                                      showPeerMenu(context, p.id, rType);
                                    }),
                              ],
                            ).paddingSymmetric(vertical: 8.0, horizontal: 12.0)
                          ],
                        ),
                      ),
                    ),
                  ))),
        ),
      ));
    });
    return SingleChildScrollView(
        child: Wrap(children: cards, spacing: space, runSpacing: space));
  }

  /// Show the peer menu and handle user's choice.
  /// User might remove the peer or send a file to the peer.
  void showPeerMenu(BuildContext context, String id, RemoteType rType) async {
    var items = [
      PopupMenuItem<String>(
          child: Text(translate('Connect')), value: 'connect'),
      PopupMenuItem<String>(
          child: Text(translate('Transfer File')), value: 'file'),
      PopupMenuItem<String>(
          child: Text(translate('TCP Tunneling')), value: 'tcp-tunnel'),
      PopupMenuItem<String>(child: Text(translate('Rename')), value: 'rename'),
      rType == RemoteType.addressBook
          ? PopupMenuItem<String>(
              child: Text(translate('Remove')), value: 'ab-delete')
          : PopupMenuItem<String>(
              child: Text(translate('Remove')), value: 'remove'),
      PopupMenuItem<String>(
          child: Text(translate('Unremember Password')),
          value: 'unremember-password'),
    ];
    if (rType == RemoteType.favorite) {
      items.add(PopupMenuItem<String>(
          child: Text(translate('Remove from Favorites')),
          value: 'remove-fav'));
    } else if (rType != RemoteType.addressBook) {
      items.add(PopupMenuItem<String>(
          child: Text(translate('Add to Favorites')), value: 'add-fav'));
    } else {
      items.add(PopupMenuItem<String>(
          child: Text(translate('Edit Tag')), value: 'ab-edit-tag'));
    }
    var value = await showMenu(
      context: context,
      position: this._menuPos,
      items: items,
      elevation: 8,
    );
    if (value == 'remove') {
      setState(() => gFFI.setByName('remove', '$id'));
      () async {
        removePreference(id);
      }();
    } else if (value == 'file') {
      connect(id, isFileTransfer: true);
    } else if (value == 'add-fav') {
    } else if (value == 'connect') {
      connect(id, isFileTransfer: false);
    } else if (value == 'ab-delete') {
      gFFI.abModel.deletePeer(id);
      await gFFI.abModel.updateAb();
      setState(() {});
    } else if (value == 'ab-edit-tag') {
      abEditTag(id);
    }
  }

  var svcStopped = false.obs;
  var svcStatusCode = 0.obs;
  var svcIsUsingPublicServer = true.obs;

  Widget buildStatus() {
    final light = Container(
      height: 8,
      width: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.green,
      ),
    ).paddingSymmetric(horizontal: 8.0);
    if (svcStopped.value) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [light, Text(translate("Service is not running"))],
      );
    } else {
      if (svcStatusCode.value == 0) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [light, Text(translate("connecting_status"))],
        );
      } else if (svcStatusCode.value == -1) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [light, Text(translate("not_ready_status"))],
        );
      }
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        light,
        Text("${translate('Ready')}"),
        svcIsUsingPublicServer.value
            ? InkWell(
                onTap: onUsePublicServerGuide,
                child: Text(
                  ', ${translate('setup_server_tip')}',
                  style: TextStyle(decoration: TextDecoration.underline),
                ),
              )
            : Offstage()
      ],
    );
  }

  void onUsePublicServerGuide() {
    final url = "https://rustdesk.com/blog/id-relay-set/";
    canLaunchUrlString(url).then((can) {
      if (can) {
        launchUrlString(url);
      }
    });
  }

  updateStatus() async {
    svcStopped.value = gFFI.getOption("stop-service") == "Y";
    final status = jsonDecode(await gFFI.bind.mainGetConnectStatus())
        as Map<String, dynamic>;
    svcStatusCode.value = status["status_num"];
    svcIsUsingPublicServer.value = await gFFI.bind.mainIsUsingPublicServer();
  }

  handleLogin() {
    loginDialog().then((success) {
      if (success) {
        setState(() {});
      }
    });
  }

  Future<Widget> buildAddressBook(BuildContext context) async {
    final token = await gFFI.getLocalOption('access_token');
    if (token.trim().isEmpty) {
      return Center(
        child: InkWell(
          onTap: handleLogin,
          child: Text(
            translate("Login"),
            style: TextStyle(decoration: TextDecoration.underline),
          ),
        ),
      );
    }
    final model = gFFI.abModel;
    return FutureBuilder(
        future: model.getAb(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return _buildAddressBook(context);
          } else if (snapshot.hasError) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(translate("${snapshot.error}")),
                TextButton(
                    onPressed: () {
                      setState(() {});
                    },
                    child: Text(translate("Retry")))
              ],
            );
          } else {
            if (model.abLoading) {
              return Center(
                child: CircularProgressIndicator(),
              );
            } else if (model.abError.isNotEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(translate("${model.abError}")),
                    TextButton(
                        onPressed: () {
                          setState(() {});
                        },
                        child: Text(translate("Retry")))
                  ],
                ),
              );
            } else {
              return Offstage();
            }
          }
        });
  }

  Widget _buildAddressBook(BuildContext context) {
    return Row(
      children: [
        Card(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: MyTheme.grayBg)),
          color: Colors.white,
          child: Container(
            width: 200,
            height: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(translate('Tags')),
                    InkWell(
                      child: PopupMenuButton(
                          itemBuilder: (context) => [
                                PopupMenuItem(
                                  child: Text(translate("Add ID")),
                                  value: 'add-id',
                                ),
                                PopupMenuItem(
                                  child: Text(translate("Add Tag")),
                                  value: 'add-tag',
                                ),
                                PopupMenuItem(
                                  child: Text(translate("Unselect all tags")),
                                  value: 'unset-all-tag',
                                ),
                              ],
                          onSelected: handleAbOp,
                          child: Icon(Icons.more_vert_outlined)),
                    )
                  ],
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                        border: Border.all(color: MyTheme.darkGray)),
                    child: Obx(
                      () => Wrap(
                        children: gFFI.abModel.tags
                            .map((e) => buildTag(e, gFFI.abModel.selectedTags,
                                    onTap: () {
                                  //
                                  if (gFFI.abModel.selectedTags.contains(e)) {
                                    gFFI.abModel.selectedTags.remove(e);
                                  } else {
                                    gFFI.abModel.selectedTags.add(e);
                                  }
                                }))
                            .toList(),
                      ),
                    ),
                  ).marginSymmetric(vertical: 8.0),
                )
              ],
            ),
          ),
        ).marginOnly(right: 8.0),
        Expanded(
          child: FutureBuilder<Widget>(
              future: getPeers(rType: RemoteType.addressBook),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Expanded(child: snapshot.data!)],
                  );
                } else if (snapshot.hasError) {
                  return Container(
                      alignment: Alignment.center,
                      child: Text('${snapshot.error}'));
                } else {
                  return Container(
                      alignment: Alignment.center,
                      child: CircularProgressIndicator());
                }
              }),
        )
      ],
    );
  }

  Widget buildTag(String tagName, RxList<dynamic> rxTags, {Function()? onTap}) {
    return ContextMenuArea(
      width: 100,
      builder: (context) => [
        ListTile(
          title: Text(translate("Delete")),
          onTap: () {
            gFFI.abModel.deleteTag(tagName);
            gFFI.abModel.updateAb();
            Future.delayed(Duration.zero, () => Get.back());
          },
        )
      ],
      child: GestureDetector(
        onTap: onTap,
        child: Obx(
          () => Container(
            decoration: BoxDecoration(
                color: rxTags.contains(tagName) ? Colors.blue : null,
                border: Border.all(color: MyTheme.darkGray),
                borderRadius: BorderRadius.circular(10)),
            margin: EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
            padding: EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
            child: Text(
              tagName,
              style: TextStyle(
                  color: rxTags.contains(tagName) ? MyTheme.white : null),
            ),
          ),
        ),
      ),
    );
  }

  /// tag operation
  void handleAbOp(String value) {
    if (value == 'add-id') {
      abAddId();
    } else if (value == 'add-tag') {
      abAddTag();
    } else if (value == 'unset-all-tag') {
      gFFI.abModel.unsetSelectedTags();
    }
  }

  void abAddId() async {
    var field = "";
    var msg = "";
    var isInProgress = false;
    DialogManager.show((setState, close) {
      return CustomAlertDialog(
        title: Text(translate("Add ID")),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(translate("whitelist_sep")),
            SizedBox(
              height: 8.0,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (s) {
                      field = s;
                    },
                    maxLines: null,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      errorText: msg.isEmpty ? null : translate(msg),
                    ),
                    controller: TextEditingController(text: field),
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 4.0,
            ),
            Offstage(offstage: !isInProgress, child: LinearProgressIndicator())
          ],
        ),
        actions: [
          TextButton(
              onPressed: () {
                close();
              },
              child: Text(translate("Cancel"))),
          TextButton(
              onPressed: () async {
                setState(() {
                  msg = "";
                  isInProgress = true;
                });
                field = field.trim();
                if (field.isEmpty) {
                  // pass
                } else {
                  final ids = field.trim().split(RegExp(r"[\s,;\n]+"));
                  field = ids.join(',');
                  for (final newId in ids) {
                    if (gFFI.abModel.idContainBy(newId)) {
                      continue;
                    }
                    gFFI.abModel.addId(newId);
                  }
                  await gFFI.abModel.updateAb();
                  this.setState(() {});
                  // final currentPeers
                }
                close();
              },
              child: Text(translate("OK"))),
        ],
      );
    });
  }

  void abAddTag() async {
    var field = "";
    var msg = "";
    var isInProgress = false;
    DialogManager.show((setState, close) {
      return CustomAlertDialog(
        title: Text(translate("Add Tag")),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(translate("whitelist_sep")),
            SizedBox(
              height: 8.0,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (s) {
                      field = s;
                    },
                    maxLines: null,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      errorText: msg.isEmpty ? null : translate(msg),
                    ),
                    controller: TextEditingController(text: field),
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 4.0,
            ),
            Offstage(offstage: !isInProgress, child: LinearProgressIndicator())
          ],
        ),
        actions: [
          TextButton(
              onPressed: () {
                close();
              },
              child: Text(translate("Cancel"))),
          TextButton(
              onPressed: () async {
                setState(() {
                  msg = "";
                  isInProgress = true;
                });
                field = field.trim();
                if (field.isEmpty) {
                  // pass
                } else {
                  final tags = field.trim().split(RegExp(r"[\s,;\n]+"));
                  field = tags.join(',');
                  for (final tag in tags) {
                    gFFI.abModel.addTag(tag);
                  }
                  await gFFI.abModel.updateAb();
                  // final currentPeers
                }
                close();
              },
              child: Text(translate("OK"))),
        ],
      );
    });
  }

  void abEditTag(String id) {
    var isInProgress = false;

    final tags = List.of(gFFI.abModel.tags);
    var selectedTag = gFFI.abModel.getPeerTags(id).obs;

    DialogManager.show((setState, close) {
      return CustomAlertDialog(
        title: Text(translate("Edit Tag")),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Wrap(
                children: tags
                    .map((e) => buildTag(e, selectedTag, onTap: () {
                          if (selectedTag.contains(e)) {
                            selectedTag.remove(e);
                          } else {
                            selectedTag.add(e);
                          }
                        }))
                    .toList(growable: false),
              ),
            ),
            Offstage(offstage: !isInProgress, child: LinearProgressIndicator())
          ],
        ),
        actions: [
          TextButton(
              onPressed: () {
                close();
              },
              child: Text(translate("Cancel"))),
          TextButton(
              onPressed: () async {
                setState(() {
                  isInProgress = true;
                });
                gFFI.abModel.changeTagForPeer(id, selectedTag);
                await gFFI.abModel.updateAb();
                close();
              },
              child: Text(translate("OK"))),
        ],
      );
    });
  }
}

class WebMenu extends StatefulWidget {
  @override
  _WebMenuState createState() => _WebMenuState();
}

class _WebMenuState extends State<WebMenu> {
  @override
  Widget build(BuildContext context) {
    Provider.of<FfiModel>(context);
    final username = getUsername();
    return PopupMenuButton<String>(
        icon: Icon(Icons.more_vert),
        itemBuilder: (context) {
          return (isIOS
                  ? [
                      PopupMenuItem(
                        child: Icon(Icons.qr_code_scanner, color: Colors.black),
                        value: "scan",
                      )
                    ]
                  : <PopupMenuItem<String>>[]) +
              [
                PopupMenuItem(
                  child: Text(translate('ID/Relay Server')),
                  value: "server",
                )
              ] +
              (getUrl().contains('admin.rustdesk.com')
                  ? <PopupMenuItem<String>>[]
                  : [
                      PopupMenuItem(
                        child: Text(username == null
                            ? translate("Login")
                            : translate("Logout") + ' ($username)'),
                        value: "login",
                      )
                    ]) +
              [
                PopupMenuItem(
                  child: Text(translate('About') + ' RustDesk'),
                  value: "about",
                )
              ];
        },
        onSelected: (value) {
          if (value == 'server') {
            showServerSettings();
          }
          if (value == 'about') {
            showAbout();
          }
          if (value == 'login') {
            if (username == null) {
              showLogin();
            } else {
              logout();
            }
          }
          if (value == 'scan') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (BuildContext context) => ScanPage(),
              ),
            );
          }
        });
  }
}
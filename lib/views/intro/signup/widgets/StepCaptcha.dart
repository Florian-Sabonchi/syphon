import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:equatable/equatable.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:redux/redux.dart';

import 'package:syphon/global/assets.dart';
import 'package:syphon/global/colours.dart';
import 'package:syphon/global/dimensions.dart';

import 'package:syphon/global/strings.dart';
import 'package:syphon/store/index.dart';
import 'package:syphon/views/widgets/buttons/button-text.dart';
import 'package:syphon/views/widgets/dialogs/dialog-captcha.dart';
import 'package:syphon/views/widgets/dialogs/dialog-confirm.dart';

class CaptchaStep extends StatefulWidget {
  const CaptchaStep({Key? key}) : super(key: key);

  @override
  CaptchaStepState createState() => CaptchaStepState();
}

class CaptchaStepState extends State<CaptchaStep> {
  final focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) => StoreConnector<AppState, _Props>(
      distinct: true,
      converter: (Store<AppState> store) => _Props.mapStateToProps(store),
      builder: (context, props) {
        final double width = MediaQuery.of(context).size.width;

        return Flex(
          direction: Axis.vertical,
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Flexible(
              flex: 6,
              child: Container(
                width: width * 0.75,
                constraints: BoxConstraints(
                  maxHeight: Dimensions.mediaSizeMax,
                  maxWidth: Dimensions.mediaSizeMax,
                ),
                child: SvgPicture.asset(
                  Assets.heroAcceptTerms,
                  semanticsLabel: Strings.labelTermsOfService,
                ),
              ),
            ),
            Flexible(
              flex: 2,
              child: Flex(
                direction: Axis.vertical,
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  Container(
                    padding: EdgeInsets.only(bottom: 8, top: 8),
                    child: Text(
                      Strings.contentCaptchaRequirement,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.caption,
                    ),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 24,
                        ),
                        child: Text(
                          'Confirm you\'re alive',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headline5,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (dialogContext) => DialogConfirm(
                                title: Strings.titleDialogCaptcha,
                                content: Strings.contentCaptchaWarning,
                                onConfirm: () => Navigator.pop(dialogContext),
                                onDismiss: () => Navigator.pop(dialogContext),
                              ),
                            );
                          },
                          child: Container(
                            height: 20,
                            width: 20,
                            child: Icon(
                              Icons.info_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Flexible(
              flex: 1,
              child: Flex(
                direction: Axis.vertical,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  ButtonText(
                    text: !props.completed
                        ? Strings.buttonTextLoadCaptcha
                        : Strings.buttonTextConfirmed,
                    color: !props.completed
                        ? Color(Colours.cyanSyphon)
                        : Color(Colours.cyanSyphonAlpha),
                    loading: props.loading,
                    disabled: props.completed,
                    onPressed: () => props.onShowCaptcha(
                      context,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      });
}

class _Props extends Equatable {
  final bool loading;
  final bool completed;

  final Function onShowCaptcha;

  const _Props({
    required this.loading,
    required this.completed,
    required this.onShowCaptcha,
  });

  @override
  List<Object> get props => [
        loading,
        completed,
      ];

  static _Props mapStateToProps(Store<AppState> store) => _Props(
        loading: store.state.authStore.loading,
        completed: store.state.authStore.captcha,
        onShowCaptcha: (BuildContext context) async {
          final authSession = store.state.authStore.authSession;
          await showDialog(
            context: context,
            builder: (context) {
              return DialogCaptcha(
                key: Key(authSession!),
              );
            },
          );
        },
      );
}

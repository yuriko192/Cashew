import 'dart:async';

import 'package:budget/functions.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/struct/firebaseAuthGlobal.dart';
import 'package:budget/struct/languageMap.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/animatedExpanded.dart';
import 'package:budget/widgets/button.dart';
import 'package:budget/widgets/fadeIn.dart';
import 'package:budget/widgets/globalSnackbar.dart';
import 'package:budget/widgets/navigationFramework.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/widgets/openSnackbar.dart';
import 'package:budget/widgets/showChangelog.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:budget/widgets/textInput.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:budget/colors.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:budget/widgets/framework/popupFramework.dart';

final InAppReview inAppReview = InAppReview.instance;

bool openRatingPopupCheck(BuildContext context) {
  // Disable this for now, we have the new in-home page review popup
  return false;
  if ((appStateSettings["numLogins"] + 1) % 10 == 0 &&
      appStateSettings["submittedFeedback"] != true) {
    openBottomSheet(context, RatingPopup(), fullSnap: true);
    return true;
  }
  return false;
}

class RatingPopup extends StatefulWidget {
  const RatingPopup({super.key});

  @override
  State<RatingPopup> createState() => _RatingPopupState();
}

class _RatingPopupState extends State<RatingPopup> {
  int? selectedStars = null;
  bool writingFeedback = false;
  TextEditingController _feedbackController = TextEditingController();
  TextEditingController _feedbackControllerEmail = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return PopupFramework(
      title: "rate-app".tr(namedArgs: {"app": globalAppName}),
      subtitle: "rate-app-subtitle".tr(namedArgs: {"app": globalAppName}),
      child: Column(
        children: [
          ScalingStars(
            selectedStars: selectedStars,
            onTap: (i) {
              setState(() {
                selectedStars = i;
              });
            },
            size: getWidthBottomSheet(context) - 100 < 60 * 5
                ? (getWidthBottomSheet(context) - 100) / 5
                : 60,
            color: appStateSettings["materialYou"]
                ? Theme.of(context).colorScheme.primary.withOpacity(0.7)
                : getColor(context, "starYellow"),
          ),
          SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadiusDirectional.circular(
                getPlatform() == PlatformOS.isIOS ? 8 : 15),
            child: Column(
              children: [
                TextInput(
                  borderRadius: BorderRadius.zero,
                  padding: EdgeInsetsDirectional.zero,
                  labelText: "feedback-suggestions-questions".tr(),
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  minLines: 3,
                  controller: _feedbackController,
                  onChanged: (value) {
                    if (writingFeedback == false) {
                      setState(() {
                        writingFeedback = true;
                      });
                      bottomSheetControllerGlobal.snapToExtent(0);
                    }
                  },
                ),
                if (appStateSettings["showFAQAndHelpLink"] == true)
                  HorizontalBreak(
                    padding: EdgeInsetsDirectional.zero,
                    color: appStateSettings["materialYou"]
                        ? dynamicPastel(
                            context,
                            Theme.of(context).colorScheme.secondaryContainer,
                            amount: 0.1,
                            inverse: true,
                          )
                        : getColor(context, "lightDarkAccent"),
                  ),
                if (appStateSettings["showFAQAndHelpLink"] == true)
                  LinkInNotes(
                    color: (appStateSettings["materialYou"]
                        ? Theme.of(context).colorScheme.secondaryContainer
                        : getColor(context, "canvasContainer")),
                    link: "guide-and-faq".tr(),
                    iconData: appStateSettings["outlinedIcons"]
                        ? Icons.live_help_outlined
                        : Icons.live_help_rounded,
                    iconDataAfter: appStateSettings["outlinedIcons"]
                        ? Icons.open_in_new_outlined
                        : Icons.open_in_new_rounded,
                    onTap: () async {
                      openUrl("https://cashewapp.web.app/faq.html");
                    },
                  ),
              ],
            ),
          ),
          SizedBox(height: 10),
          AnimatedExpanded(
            expand: writingFeedback,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 10),
              child: TextInput(
                labelText: "email-optional".tr(),
                padding: EdgeInsetsDirectional.zero,
                controller: _feedbackControllerEmail,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
              ),
            ),
          ),
          Opacity(
            opacity: 0.4,
            child: AnimatedSizeSwitcher(
              child: TextFont(
                key: ValueKey(writingFeedback.toString()),
                text: writingFeedback
                    ? "rate-app-privacy-email".tr()
                    : "rate-app-privacy".tr(),
                textAlign: TextAlign.center,
                fontSize: 12,
                maxLines: 5,
              ),
            ),
          ),
          SizedBox(height: 15),
          Button(
            label: "submit".tr(),
            onTap: () async {
              // Remind user to provide email
              if (_feedbackController.text != "" &&
                  _feedbackControllerEmail.text == "") {
                dynamic result = await openPopup(
                  context,
                  icon: appStateSettings["outlinedIcons"]
                      ? Icons.email_outlined
                      : Icons.email_rounded,
                  title: "provide-email-question".tr(),
                  description: "provide-email-question-description".tr(),
                  onCancelLabel: "submit-anyway".tr(),
                  onCancel: () {
                    Navigator.maybePop(context, true);
                  },
                  onSubmitLabel: "go-back".tr(),
                  onSubmit: () {
                    Navigator.maybePop(context, false);
                  },
                );
                if (result == false) return;
              }

              Navigator.maybePop(context);

              shareFeedback(
                _feedbackController.text,
                "rating",
                feedbackEmail: _feedbackControllerEmail.text,
                selectedStars: selectedStars,
              );
            },
            disabled: selectedStars == null,
          )
        ],
      ),
    );
  }
}

Future<bool> shareFeedback(String feedbackText, String feedbackType,
    {String? feedbackEmail, int? selectedStars}) async {
  loadingIndeterminateKey.currentState?.setVisibility(true);
  bool error = false;

  try {
    if ((selectedStars ?? 0) >= 4) {
      if (await inAppReview.isAvailable()) inAppReview.requestReview();
    }
  } catch (e) {
    print(e.toString());
    error = true;
  }

  try {
    FirebaseFirestore? db = await firebaseGetDBInstanceAnonymous();
    if (db == null) {
      throw ("Can't connect to db");
    }
    Map<String, dynamic> feedbackEntry = {
      "stars": (selectedStars ?? -1) + 1,
      "feedback": feedbackText,
      "dateTime": DateTime.now(),
      "feedbackType": feedbackType,
      "email": feedbackEmail,
      "platform": getPlatform().toString(),
      "appVersion": getVersionString(),
    };

    DocumentReference feedbackCreatedOnCloud =
        await db.collection("feedback").add(feedbackEntry);

    openSnackbar(SnackbarMessage(
        title: "feedback-shared".tr(),
        description: "thank-you".tr(),
        icon: appStateSettings["outlinedIcons"]
            ? Icons.rate_review_outlined
            : Icons.rate_review_rounded,
        timeout: Duration(milliseconds: 2500)));
  } catch (e) {
    print(e.toString());
    error = true;
  }
  if (error == true) {
    print("Error leaving review on store");
    openSnackbar(SnackbarMessage(
        title: "Error Sharing Feedback",
        description: "Please try again later",
        icon: appStateSettings["outlinedIcons"]
            ? Icons.warning_outlined
            : Icons.warning_rounded,
        timeout: Duration(milliseconds: 2500)));
  }
  loadingIndeterminateKey.currentState?.setVisibility(false);

  if (selectedStars != -1) {
    updateSettings("submittedFeedback", true,
        pagesNeedingRefresh: [], updateGlobalState: false);
  }

  return true;
}

class ScalingStars extends StatelessWidget {
  const ScalingStars(
      {required this.selectedStars,
      required this.onTap,
      required this.size,
      required this.color,
      this.loop = false,
      this.loopDelay = Duration.zero,
      super.key});
  final int? selectedStars;
  final Function(int index) onTap;
  final double size;
  final Color color;
  final bool loop;
  final Duration loopDelay;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < 5; i++)
          Tappable(
            color: Colors.transparent,
            borderRadius: 100,
            onTap: () => onTap(i),
            child: ScaleIn(
              loop: loop,
              loopDelay: loopDelay,
              delay: Duration(milliseconds: 300 + 100 * i),
              child: ScalingWidget(
                keyToWatch: (i <= (selectedStars ?? 0)).toString(),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    appStateSettings["outlinedIcons"]
                        ? Icons.star_outlined
                        : Icons.star_rounded,
                    key: ValueKey(i <= (selectedStars ?? -1)),
                    size: size,
                    color: selectedStars != null && i <= (selectedStars ?? 0)
                        ? color
                        : appStateSettings["materialYou"]
                            ? Theme.of(context)
                                .colorScheme
                                .secondary
                                .withOpacity(0.2)
                            : getColor(context, "lightDarkAccentHeavy"),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

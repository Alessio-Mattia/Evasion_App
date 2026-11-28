import 'package:evasion/core/widgets/page_indicator.dart';
import 'package:evasion/features/profile/domain/profile_page.dart';
import 'package:evasion/features/profile/domain/public_profile.dart';
import 'package:evasion/features/profile/presentation/carousel/add_page_card.dart';
import 'package:evasion/features/profile/presentation/carousel/main_page_card.dart';
import 'package:evasion/features/profile/presentation/carousel/page_cards.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// The profile carousel: the page built from the profile, then the free pages,
/// then, on the own profile, a card to add one.
///
/// It does not loop, so that the dots tell where the user is. The next page
/// shows at the right edge, to suggest swiping.
class ProfileCarousel extends StatefulWidget {
  const ProfileCarousel({
    required this.profile,
    required this.pages,
    this.onAddPage,
    this.onLongPressPage,
    super.key,
  });

  final PublicProfile profile;
  final List<ProfilePage> pages;

  /// Shows the add card at the end. Null on the profile of someone else.
  final VoidCallback? onAddPage;

  /// Called on a long press on any page, including the one built from the
  /// profile. Null on the profile of someone else.
  final VoidCallback? onLongPressPage;

  @override
  State<ProfileCarousel> createState() => _ProfileCarouselState();
}

class _ProfileCarouselState extends State<ProfileCarousel> {
  final _controller = PageController(viewportFraction: 0.88);
  int _current = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onAddPage = widget.onAddPage;
    final pageCount = widget.pages.length + 1;
    final count = pageCount + (onAddPage != null ? 1 : 0);
    final current = _current.clamp(0, count - 1);
    final pageWidth = MediaQuery.sizeOf(context).width * 0.88;

    return Column(
      spacing: 12,
      children: [
        SizedBox(
          // Portrait pages, 4:5 like most profile photos.
          height: pageWidth * 5 / 4,
          child: PageView.builder(
            controller: _controller,
            padEnds: false,
            itemCount: count,
            onPageChanged: (index) => setState(() => _current = index),
            itemBuilder: (context, index) => switch (index) {
              _ when index < pageCount => _LongPressable(
                onLongPress: widget.onLongPressPage,
                child: index == 0
                    ? MainPageCard(profile: widget.profile)
                    : PageCard(page: widget.pages[index - 1]),
              ),
              _ => AddPageCard(onTap: onAddPage!),
            },
          ),
        ),
        if (count > 1)
          PageIndicator(
            count: count,
            current: current,
            semanticsLabel: AppLocalizations.of(context)
                .profilePageIndicator(current + 1, count),
          ),
      ],
    );
  }
}

/// A page that opens the edit mode on a long press. Screen readers announce
/// it, since the gesture is not visible.
class _LongPressable extends StatelessWidget {
  const _LongPressable({required this.onLongPress, required this.child});

  final VoidCallback? onLongPress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final onLongPress = this.onLongPress;
    if (onLongPress == null) return child;
    return Semantics(
      onLongPressHint: AppLocalizations.of(context).profileManageHint,
      child: GestureDetector(onLongPress: onLongPress, child: child),
    );
  }
}

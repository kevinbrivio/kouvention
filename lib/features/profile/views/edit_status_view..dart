import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/cores/widgets/custom_app_bar.dart';
import 'package:kouvention/cores/widgets/custom_button.dart';
import 'package:kouvention/cores/widgets/custom_divider.dart';
import 'package:kouvention/cores/widgets/custom_text_field.dart';
import 'package:kouvention/features/profile/viewmodel/edit_status_viewmodel.dart';

class EditStatusView extends StatefulWidget {
  final String? currentStatus;
  const EditStatusView({super.key, this.currentStatus});

  @override
  State<EditStatusView> createState() => _EditNameViewState();
}

class _EditNameViewState extends State<EditStatusView> {
  @override
  Widget build(BuildContext context) => BaseView(
    appBar: (_) => _buildAppBar(),
    useGradient: false,
    provider: editStatusVM,
    builder: _buildBody,
  );

  Widget _buildBody(BuildContext context, EditStatusVM vm) => SafeArea(
    child: Padding(
      padding: EdgeInsets.only(
        left: AppRadius.xl.w,
        right: AppRadius.xl.w,
        // top: MediaQuery.of(context).padding.top,
        bottom: MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Field
                  Form(
                    key: vm.formKey,
                    child: CustomTextField(
                      hint: widget.currentStatus ?? 'What\'s happening?',
                      label: '',
                      inputModel: vm.form.status,
                      onSubmit: (val) => vm.editStatus(context),
                    ),
                  ),
                  Gap(AppSpacing.xs.h),
                  Text(
                    'Visible in chats',
                    style: context.text.labelSmall.copyWith(color: context.text.tertiaryText),
                  ),
                  Gap(AppSpacing.xs.h),
                  CustomDivider(),
                  Gap(AppSpacing.xs.h),
                  Text('Select', style: context.text.labelSmall.copyWith(color: context.text.tertiaryText)),
                  Gap(AppSpacing.xs.h),
                  _buildDefaultStatus(vm),
                  Gap(AppSpacing.md.h),
                ],
              ),
            ),
          ),
          Button(text: 'Save', onPressed: () => vm.editStatus(context)),
        ],
      ),
    ),
  );

  PreferredSizeWidget _buildAppBar() => CustomAppBar(
    body: Text('About', style: context.text.appBarTitle),
    onBack: () => context.go(RouterRoutes.profile.path),
  );

  Widget _buildDefaultStatus(EditStatusVM vm) => ListView.separated(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: _defaultStatuses.length,
    separatorBuilder: (_, __) => Divider(
      height: AppSpacing.md.h,
      thickness: 0.5,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5).withValues(alpha: 0.3),
    ),
    itemBuilder: (context, index) {
      final status = _defaultStatuses[index];
      return InkWell(
        onTap: () => vm.onStatusSelected(status),
        child: Row(
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: status.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(status.emoji, style: context.text.labelSmall.copyWith(color: context.text.tertiaryText)),
            ),
            Gap(AppSpacing.sm.w),
            Text(status.label, style: context.text.labelSmall.copyWith(color: context.text.tertiaryText)),
          ],
        ),
      );
    },
  );
}

class DefaultStatus {
  final String emoji;
  final String label;
  final Color color;

  const DefaultStatus({
    required this.emoji,
    required this.label,
    required this.color,
  });
}

const List<DefaultStatus> _defaultStatuses = [
  DefaultStatus(emoji: '💬', label: 'Free to chat', color: Color(0xFF1565C0)),
  DefaultStatus(
    emoji: '🐢',
    label: 'Slow to Respond',
    color: Color(0xFF2E7D32),
  ),
  DefaultStatus(
    emoji: '👯',
    label: 'Hanging with friends',
    color: Color(0xFF6A1B9A),
  ),
  DefaultStatus(emoji: '✈️', label: 'Traveling', color: Color(0xFFEF6C00)),
  DefaultStatus(emoji: '🎉', label: 'Excited', color: Color(0xFFC62828)),
];

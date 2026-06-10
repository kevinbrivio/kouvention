import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/cores/widgets/custom_app_bar.dart';
import 'package:kouvention/cores/widgets/custom_button.dart';
import 'package:kouvention/cores/widgets/custom_text_field.dart';
import 'package:kouvention/features/profile/viewmodel/edit_name_viewmodel.dart';

class EditNameView extends StatefulWidget {
  final String currentName;
  const EditNameView({super.key, required this.currentName});

  @override
  State<EditNameView> createState() => _EditNameViewState();
}

class _EditNameViewState extends State<EditNameView> {
  @override
  Widget build(BuildContext context) => BaseView(
    appBar: (_) => _buildAppBar(),
    useGradient: false,
    provider: editNameVM,
    builder: _buildBody,
  );

  Widget _buildBody(BuildContext context, EditNameVM vm) => SafeArea(
    child: Padding(
      padding: EdgeInsets.only(
        left: AppRadius.xl.w,
        right: AppRadius.xl.w,
        top: MediaQuery.of(context).padding.top,
        bottom: MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name Field
                Form(
                  key: vm.formKey,
                  child: CustomTextField(
                    hint: widget.currentName,
                    label: 'Your name',
                    inputModel: vm.form.name,
                    onSubmit: (val) => vm.editName(context),
                  ),
                ),
                Gap(AppSpacing.xs.h),
                Text(
                  'People will see this name if you interact with them.',
                  style: context.text.subDescription3,
                ),
              ],
            ),
          ),
          Button(text: 'Save', onPressed: () => vm.editName(context)),
        ],
      ),
    ),
  );

  PreferredSizeWidget _buildAppBar() => CustomAppBar(
    body: Text('Name', style: context.text.appBar),
    onBack: () => context.go(RouterRoutes.profile.path),
  );
}

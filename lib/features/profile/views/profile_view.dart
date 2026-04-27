import 'package:flutter/material.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/features/profile/viewmodel/profile_viewmodel.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) =>
      BaseView(provider: profileVM, builder: (context, vm) => _ProfileBody(viewmodel: vm));
}

class _ProfileBody extends StatefulWidget {
  final ProfileVM viewmodel;
  
  _ProfileBody({
    super.key,
    required this.viewmodel
  });
  
  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
@override
  Widget build(BuildContext context) => Column(
    
  );
}

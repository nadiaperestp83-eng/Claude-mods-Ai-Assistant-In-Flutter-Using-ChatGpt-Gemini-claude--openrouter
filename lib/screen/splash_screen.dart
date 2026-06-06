import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../helper/global.dart';
import '../helper/pref.dart';
import '../widget/custom_loading.dart';
import 'feature/chatbot/chatbot_feature.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      Pref.showOnboarding = false;
      Get.off(() => const ChatBotFeature());
    });
  }

  @override
  Widget build(BuildContext context) {
    mq = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F4FD),
              Color(0xFFF0E6FF),
              Color(0xFFFFE8F0),
            ],
          ),
        ),
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            children: [
              const Spacer(flex: 2),
              Card(
                elevation: 8,
                shadowColor: Colors.blue.withOpacity(0.3),
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24))),
                child: Padding(
                  padding: EdgeInsets.all(mq.width * .05),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: mq.width * .4,
                  ),
                ),
              ),
              const Spacer(),
              const CustomLoading(),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

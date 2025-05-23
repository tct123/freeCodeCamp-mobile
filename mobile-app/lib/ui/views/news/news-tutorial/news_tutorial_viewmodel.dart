import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:freecodecamp/app/app.locator.dart';
import 'package:freecodecamp/models/news/tutorial_model.dart';
import 'package:freecodecamp/service/news/api_service.dart';
import 'package:freecodecamp/ui/views/news/html_handler/html_handler.dart';
import 'package:freecodecamp/ui/views/news/news-tutorial/news_tutorial_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stacked/stacked.dart';

class NewsTutorialViewModel extends BaseViewModel {
  late Future<Tutorial> _tutorialFuture;
  final _newsApiService = locator<NewsApiService>();

  Future<Tutorial>? get tutorialFuture => _tutorialFuture;

  final ScrollController _scrollController = ScrollController();
  ScrollController get scrollController => _scrollController;

  final ScrollController _bottomButtonController = ScrollController();
  ScrollController get bottomButtonController => _bottomButtonController;

  bool _showToTopButton = false;
  bool get showToTopButton => _showToTopButton;

  set showToTopButton(bool value) {
    _showToTopButton = value;
    notifyListeners();
  }

  Future<Tutorial> readFromFiles() async {
    String json = await rootBundle.loadString(
      'assets/test_data/news_post.json',
    );

    var decodedJson = jsonDecode(json);

    return Tutorial.toPostFromJson(decodedJson);
  }

  Future<Tutorial> initState(id) async {
    handleBottomButtonAnimation();
    handleToTopButton();

    // if (await _developerService.developmentMode()) {
    //   return readFromFiles();
    // } else {
    // }
    return fetchTutorial(id);
  }

  Future<void> handleToTopButton() async {
    _scrollController.addListener(() {
      if (scrollController.offset >= 100) {
        if (!showToTopButton) {
          showToTopButton = true;
        }
      } else {
        if (showToTopButton) {
          showToTopButton = false;
        }
      }
    });
  }

  Future<void> goToTop() async {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOut,
    );
  }

  Future<void> handleBottomButtonAnimation() async {
    _scrollController.addListener(() async {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      if (prefs.getDouble('position') == null) {
        await prefs.setDouble('position', _scrollController.offset);
      }

      double oldScrollPos = prefs.getDouble('position') as double;

      if (_scrollController.offset <= oldScrollPos) {
        _bottomButtonController.animateTo(
          _bottomButtonController.position.maxScrollExtent - 50,
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOut,
        );
      } else {
        _bottomButtonController.animateTo(
          0,
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOut,
        );
      }
      Timer(const Duration(seconds: 2), () async {
        if (_scrollController.hasClients) {
          await prefs.setDouble('position', _scrollController.offset);
        }
      });
    });
  }

  Future<void> initBottomButtonAnimation() async {
    // if the user has not scrolled yet the bottom buttons will not appear
    // this means we need to animate it manually.
    Future.delayed(
      const Duration(seconds: 1),
      () => {
        if (_bottomButtonController.hasClients)
          {
            _bottomButtonController.animateTo(
              _bottomButtonController.position.maxScrollExtent - 50,
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeInOut,
            )
          }
      },
    );
  }

  List<Widget> initLazyLoading(html, context, tutorial) {
    HTMLParser parser = HTMLParser(context: context);

    List<Widget> elements = parser.parse(html);

    if (tutorial is Tutorial) {
      // insert before the first element
      elements.insert(
        0,
        Stack(
          children: [
            NewsTutorialHeader(tutorial: tutorial),
            AppBar(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              leading: Tooltip(
                message: 'Back',
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                    child: const Icon(Icons.arrow_back),
                  ),
                ),
              ),
            )
          ],
        ),
      );

      // insert after the last element
      elements.add(const SizedBox(
        height: 100,
      ));

      initBottomButtonAnimation();
    }

    return elements;
  }

  Future<void> removeScrollPosition() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _scrollController.dispose();
    _bottomButtonController.dispose();

    await prefs.remove('position');
  }

  Future<Tutorial> fetchTutorial(tutorialId) async {
    await dotenv.load(fileName: '.env');

    dynamic postData = await _newsApiService.getPost(tutorialId);

    return Tutorial.toPostFromJson(postData);
  }
}

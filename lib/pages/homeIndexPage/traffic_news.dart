import 'package:hkbusapi/trafficnews/trafficnews.dart';
import 'package:spookyservices/helpers/language.dart';
import 'package:spookyservices/widgets/widgets.dart';



class TrafficNews extends StatefulWidget {
  const TrafficNews({super.key});

  @override
  State<TrafficNews> createState() => _TrafficNewsState();
}

class _TrafficNewsState extends State<TrafficNews> {
  Widget content = Center(child: CircularProgressIndicator());

  @override
  void initState() {
    super.initState();
    buildTrafficNews();
  }

  void buildTrafficNews() async {
    List<TrafficNewsItem> newsItems = await getTrafficNews();
    List<Card1> newsCards = [];

    for (var newsItem in newsItems) {
      newsCards.add(
        Card1(
          title: (newsItem.title != null) ? lh.ltl(newsItem.title!) : null,
          subtitle: lh.ltl(newsItem.description),
          // icon: Icons.traffic,
          contrast: (newsItem.status <= 2)// || (newsItem.title != null), // not null means important message (DATA.GOV.HK API V2)
        ),
      );
    }

    if (mounted) {
      setState(() {
        content = ListView(
          padding: const EdgeInsets.all(8),
          children: newsCards,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return content;
  }
}
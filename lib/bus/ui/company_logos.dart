import 'package:flutter/material.dart';
import 'package:hktransports/bus/model/bus_models.dart';

class CompanyLogos extends StatelessWidget {
  const CompanyLogos({
    super.key,
    required this.route,
    required this.language,
    this.height = 20,
    this.maxWidth = 80,
    this.fallbackStyle,
  });

  final RouteEntry route;
  final String language;
  final double height;
  final double maxWidth;
  final TextStyle? fallbackStyle;

  @override
  Widget build(BuildContext context) {
    final List<BusCompany> companies = route.sortedCompanies;
    final List<Widget> logos = <Widget>[];
    for (final BusCompany company in companies) {
      final String? asset = companyLogoAsset(route, company);
      if (asset == null) {
        return Text(
          route.companiesLabel(language),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: fallbackStyle,
        );
      }
      logos.add(
        Padding(
          padding: EdgeInsets.only(right: company == companies.last ? 0 : 4),
          child: _logo(context, asset),
        ),
      );
    }
    if (logos.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: route.companiesLabel(language),
      image: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(mainAxisSize: MainAxisSize.min, children: logos),
        ),
      ),
    );
  }

  Widget _logo(BuildContext context, String asset) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Widget image = Image.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      excludeFromSemantics: true,
    );
    if (!dark) return image;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(4),
      ),
      child: image,
    );
  }
}

String? companyLogoAsset(RouteEntry route, BusCompany company) {
  switch (company) {
    case BusCompany.ctb:
      return route.companyLabel(company, 'en') == 'Cityflyer'
          ? 'assets/images/companies/cityflyer.png'
          : 'assets/images/companies/citybus.png';
    case BusCompany.kmb:
      return route.companyLabel(company, 'en') == 'LWB'
          ? 'assets/images/companies/lwb.png'
          : 'assets/images/companies/kmb.png';
    case BusCompany.nlb:
      return 'assets/images/companies/nlb.png';
    case BusCompany.gmb:
      return 'assets/images/companies/green_minibus.png';
    case BusCompany.mtr:
      return 'assets/images/companies/mtr.png';
    case BusCompany.lrtfeeder:
    case BusCompany.lightRail:
    case BusCompany.sunferry:
    case BusCompany.fortuneferry:
    case BusCompany.hkkf:
      return null;
  }
}

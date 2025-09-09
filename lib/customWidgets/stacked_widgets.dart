import 'package:flutter/material.dart';

  Widget stackedWidgets(Widget main, Widget stacked1, Widget stacked2) {
    return Row(
      mainAxisSize:
          MainAxisSize.min, // Prevents the Row from expanding to full width
      crossAxisAlignment: CrossAxisAlignment
          .center, // Vertically aligns 'abc' with the stacked text
      children: [
        main,
        // This Column will stack 'def' and 'ghi' vertically
        Column(
          mainAxisSize: MainAxisSize.min, // Keeps the column height minimal
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            stacked1,
            stacked2,
          ],
        ),
       
      ],
    );
  }


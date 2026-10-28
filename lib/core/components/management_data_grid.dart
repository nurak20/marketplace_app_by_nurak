import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../app_theme.dart';

class ManagementGridColumn {
  const ManagementGridColumn({
    required this.name,
    required this.label,
    required this.width,
    this.alignment = Alignment.centerLeft,
  });

  final String name;
  final String label;
  final double width;
  final Alignment alignment;
}

/// Shared, horizontally scrollable table for Management data on web and mobile.
/// Shows all rows by default (the grid grows to fit its content).
class ManagementDataGrid extends StatefulWidget {
  const ManagementDataGrid({
    super.key,
    required this.columns,
    required this.rows,
  });

  final List<ManagementGridColumn> columns;
  final List<List<Object?>> rows;

  @override
  State<ManagementDataGrid> createState() => _ManagementDataGridState();
}

class _ManagementDataGridState extends State<ManagementDataGrid> {
  static final Color _borderColor = Colors.grey.shade400;

  late _ManagementDataSource _source;

  @override
  void initState() {
    super.initState();
    _source = _ManagementDataSource(widget.columns, widget.rows);
  }

  @override
  void didUpdateWidget(covariant ManagementDataGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    _source.update(widget.columns, widget.rows);
  }

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.zero, // no rounded corners
      side: BorderSide(color: _borderColor), // grey outer border
    ),
    child: SfDataGridTheme(
      data: SfDataGridThemeData(
        gridLineColor: _borderColor,
        gridLineStrokeWidth: 1,
      ),
      child: SfDataGrid(
        source: _source,
        columnWidthMode: ColumnWidthMode.none,
        rowHeight: 64,
        headerRowHeight: 48,
        shrinkWrapRows: true, // show all rows, height fits content
        verticalScrollPhysics:
            const NeverScrollableScrollPhysics(), // let the page scroll
        gridLinesVisibility: GridLinesVisibility.both,
        headerGridLinesVisibility: GridLinesVisibility.both,
        columns: [
          for (final column in widget.columns)
            GridColumn(
              columnName: column.name,
              width: column.width,
              label: Container(
                alignment: column.alignment,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                color: StyleColor.canvas,
                child: Text(
                  column.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: StyleColor.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .4,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _ManagementDataSource extends DataGridSource {
  _ManagementDataSource(
    List<ManagementGridColumn> columns,
    List<List<Object?>> values,
  ) : _columns = columns {
    _rows = _createRows(values);
  }

  List<ManagementGridColumn> _columns;
  List<DataGridRow> _rows = [];

  @override
  List<DataGridRow> get rows => _rows;

  void update(List<ManagementGridColumn> columns, List<List<Object?>> values) {
    _columns = columns;
    _rows = _createRows(values);
    notifyListeners();
  }

  List<DataGridRow> _createRows(List<List<Object?>> values) => [
    for (final row in values)
      DataGridRow(
        cells: [
          for (var index = 0; index < _columns.length; index++)
            DataGridCell<Object?>(
              columnName: _columns[index].name,
              value: index < row.length ? row[index] : null,
            ),
        ],
      ),
  ];

  @override
  DataGridRowAdapter buildRow(DataGridRow row) => DataGridRowAdapter(
    color: Colors.white,
    cells: [
      for (var index = 0; index < row.getCells().length; index++)
        Container(
          alignment: _columns[index].alignment,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: _cellWidget(row.getCells()[index].value),
        ),
    ],
  );

  Widget _cellWidget(Object? value) => switch (value) {
    final Widget widget => widget,
    null => const SizedBox.shrink(),
    _ => Text('$value', maxLines: 2, overflow: TextOverflow.ellipsis),
  };
}

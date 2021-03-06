// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/src/services/correction/util.dart';
import 'package:analysis_server/src/utilities/flutter.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer/src/dart/analysis/session_helper.dart';
import 'package:analyzer/src/dart/ast/utilities.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_workspace.dart';
import 'package:meta/meta.dart';

abstract class CorrectionProducer {
  CorrectionProducerContext _context;

  /// Returns the EOL to use for this [CompilationUnit].
  String get eol => utils.endOfLine;

  String get file => _context.file;

  AstNode get node => _context.node;

  ResolvedUnitResult get resolvedResult => _context.resolvedResult;

  int get selectionLength => _context.selectionLength;

  int get selectionOffset => _context.selectionOffset;

  TypeProvider get typeProvider => _context.typeProvider;

  CorrectionUtils get utils => _context.utils;

  Future<void> compute(DartChangeBuilder builder);

  void configure(CorrectionProducerContext context) {
    _context = context;
  }

  /// Return the text of the given [range] in the unit.
  String getRangeText(SourceRange range) {
    return utils.getRangeText(range);
  }

  /// Return `true` if the selection covers an operator of the given
  /// [binaryExpression].
  bool isOperatorSelected(BinaryExpression binaryExpression) {
    AstNode left = binaryExpression.leftOperand;
    AstNode right = binaryExpression.rightOperand;
    // between the nodes
    if (selectionOffset >= left.end &&
        selectionOffset + selectionLength <= right.offset) {
      return true;
    }
    // or exactly select the node (but not with infix expressions)
    if (selectionOffset == left.offset &&
        selectionOffset + selectionLength == right.end) {
      if (left is BinaryExpression || right is BinaryExpression) {
        return false;
      }
      return true;
    }
    // invalid selection (part of node, etc)
    return false;
  }
}

class CorrectionProducerContext {
  final int selectionOffset;
  final int selectionLength;
  final int selectionEnd;

  final CorrectionUtils utils;
  final String file;

  final TypeProvider typeProvider;
  final Flutter flutter;

  final AnalysisSession session;
  final AnalysisSessionHelper sessionHelper;
  final ResolvedUnitResult resolvedResult;
  final ChangeWorkspace workspace;

  AstNode _node;

  CorrectionProducerContext({
    this.selectionOffset = -1,
    this.selectionLength = 0,
    @required this.resolvedResult,
    @required this.workspace,
  })  : file = resolvedResult.path,
        flutter = Flutter.of(resolvedResult),
        session = resolvedResult.session,
        sessionHelper = AnalysisSessionHelper(resolvedResult.session),
        typeProvider = resolvedResult.typeProvider,
        selectionEnd = (selectionOffset ?? 0) + (selectionLength ?? 0),
        utils = CorrectionUtils(resolvedResult);

  AstNode get node => _node;

  bool setupCompute() {
    final locator = NodeLocator(selectionOffset, selectionEnd);
    _node = locator.searchWithin(resolvedResult.unit);
    return _node != null;
  }
}

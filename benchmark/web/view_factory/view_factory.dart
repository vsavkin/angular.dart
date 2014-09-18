library angular.benchmark.compiler;

import 'package:angular/angular.dart';
import 'package:angular/application_factory.dart';
import 'package:angular/mock/module.dart';
import 'package:benchmark_harness/benchmark_harness.dart';

import 'package:angular/change_detection/ast_parser.dart';
import 'package:angular/core/formatter.dart';
import 'package:angular/core/module_internal.dart';


import 'dart:html';
import 'dart:js' as js;


class ViewFactoryInvocaton {
  ViewFactory viewFactory;
  Scope scope;
  DirectiveInjector di;
  List<Node> elements;

  Injector injector;
  DirectiveMap directiveMap;
  Compiler compiler;

  ViewFactoryInvocaton(String template) {
    final m = new Module()
        ..bind(ComponentWithCss)
        ..bind(ComponentWithoutCss)
        ..bind(ComponentWithEmulatedShadowDomComponent)
        ..bind(EmulatedShadowDomComponentWithCss)
        ..bind(ScopeDigestTTL, toFactory: () => new ScopeDigestTTL.value(15), inject: [])
        ..bind(CompilerConfig, toValue: new CompilerConfig.withOptions(elementProbeEnabled: false));

    injector = applicationFactory().addModule(m).run();
    directiveMap = injector.get(DirectiveMap);
    compiler = injector.get(Compiler);
    scope = injector.get(Scope);

    di = new DirectiveInjector(null, injector, new DivElement(), null, null, scope, injector.get(Animate));
  }

  run(template) {
    elements = _getElements(template);
    viewFactory = compiler(elements, directiveMap);

    final childScope = scope.createChild({});

    var views = [];
    var i = 2000;
    while (i -- >= 0) {
      viewFactory(scope, di);
    }

    childScope.destroy();
  }

  List<Node > _getElements(String template) {
    var div = new DivElement()..setInnerHtml(template, treeSanitizer: new NullTreeSanitizer());
    return new List.from(div.nodes);
  }
}

final TEMPLATE_TEXT_NO_NG_BINDING = '<span>{{1 + 2}}'
    '<span ng-if="1 != 2">left</span>'
    '<span ng-if="1 != 2">right</span>'
    '</span>';

final TEMPLATE_TEXT_WITH_NG_BINDING = '<span><span ng-class="{}">{{1 + 2}}</span>'
    '<span ng-if="1 != 2">left</span>'
    '<span ng-if="1 != 2">right</span>'
    '</span>';

final TEMPLATE_NO_TEXT_WITH_NG_BINDING = '<span><span ng-class="{}"></span>'
    '<span ng-if="1 != 2">left</span>'
    '<span ng-if="1 != 2">right</span>'
    '</span>';

final TEMPLATE_COMPONENT_NO_CSS = '<component-without-css></component-without-css>';

final TEMPLATE_COMPONENT_WITH_CSS = '<component-with-css></component-with-css>';

final TEMPLATE_CONTAINER_COMPONENT = '<component-with-emulated></component-with-emulated>';


@Component(
  selector: 'component-without-css',
  template: 'empty',
  useShadowDom: true
)
class ComponentWithoutCss {
}

@Component(
  selector: 'component-with-css',
  template: 'empty',
  cssUrl: const ['css1.css', 'css2.css'],
  useShadowDom: true
)
class ComponentWithCss {
}

@Component(
  selector: 'emulated-with-css',
  template: 'empty',
  cssUrl: const ['css1.css', 'css2.css'],
  useShadowDom: false
)
class EmulatedShadowDomComponentWithCss {
}

@Component(
  selector: 'component-with-emulated',
  template: '<emulated-with-css></emulated-with-css>'
            '<emulated-with-css></emulated-with-css>'
            '<emulated-with-css></emulated-with-css>',
  useShadowDom: true
)
class ComponentWithEmulatedShadowDomComponent {
}

void main() {
  final templates = {
      "text" : TEMPLATE_TEXT_NO_NG_BINDING,
      "text + ng-binding" : TEMPLATE_TEXT_WITH_NG_BINDING,
      "ng-binding" : TEMPLATE_NO_TEXT_WITH_NG_BINDING,
      "component without css" : TEMPLATE_COMPONENT_NO_CSS,
      "component with css" : TEMPLATE_COMPONENT_WITH_CSS,
      "component with emulated shadow dom component" : TEMPLATE_CONTAINER_COMPONENT
  };

  final t = document.querySelector("#templates");
  templates.keys.forEach((name) {
    t.appendHtml("<option value='$name'>$name</option>");
  });

  final b = new ViewFactoryInvocaton(templates[t.value]);
  viewFactory(_) {
    b.run(templates[t.value]);
  }

  js.context['benchmarkSteps'].add(new js.JsObject.jsify({
      "name": "ViewFactory.call", "fn": new js.JsFunction.withThis(viewFactory)
  }));
}

part of angular.directive;

@NgDirective(
    selector: '[ng-base-css]',
    visibility: NgDirective.CHILDREN_VISIBILITY
)
class NgBaseCss implements NgAttachAware {

  List<String> _urls = const [];

  var completer = new async.Completer();

  @NgAttr('ng-base-css')
  set urls(v) {
    return _urls = v is List ? v : [v];
  }

  async.Future<List<String>> get urls {
    return completer.future;
  }

  attach() {
    completer.complete(_urls);
  }
}

class RootNgBaseCss implements NgBaseCss {
  set urls(_) { }

  get urls => new async.Future.value([]);

  attach() { }
}
